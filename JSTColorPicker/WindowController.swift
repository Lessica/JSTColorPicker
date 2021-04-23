//
//  WindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

private var windowCount = 0

class WindowController: NSWindowController {
    
    static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    weak var tabDelegate: TabDelegate!
    lazy var pixelMatchService: PixelMatchService = {
        return PixelMatchService()
    }()
    
    @objc dynamic internal weak var screenshot  : Screenshot?
    internal var documentScreenshot             : Screenshot?      { document as? Screenshot }
    private var documentState                   : Screenshot.State { screenshot?.state ?? .notLoaded }

    private var isInComparisonMode: Bool = false
    private var isScreenshotActionAllowed: Bool {
        #if APP_STORE
        return AppDelegate.shared.applicationHasScreenshotHelper() && (documentState.isReadable || !documentState.isLoaded)
        #else
        return documentState.isReadable || !documentState.isLoaded
        #endif
    }
    
    @IBOutlet weak var openItem                        : NSToolbarItem!
    @IBOutlet weak var annotateItem                    : NSToolbarItem!
    @IBOutlet weak var magnifyItem                     : NSToolbarItem!
    @IBOutlet weak var minifyItem                      : NSToolbarItem!
    @IBOutlet weak var selectItem                      : NSToolbarItem!
    @IBOutlet weak var moveItem                        : NSToolbarItem!
    @IBOutlet weak var fitWindowItem                   : NSToolbarItem!
    @IBOutlet weak var fillWindowItem                  : NSToolbarItem!
    @IBOutlet weak var screenshotItem                  : NSToolbarItem!
    
    @IBOutlet weak var mainTouchBar                    : NSTouchBar!
    @IBOutlet weak var groupedTouchBar                 : NSTouchBar!
    @IBOutlet weak var sliderTouchBar                  : NSTouchBar!
    
    @IBOutlet weak var touchBarOpenButton              : NSButton!
    @IBOutlet weak var touchBarSceneToolControl        : NSSegmentedControl!
    @IBOutlet weak var touchBarSceneActionControl      : NSSegmentedControl!
    @IBOutlet weak var touchBarScreenshot              : NSButton!
    
    internal       var previewStage                    : ItemPreviewStage = .none
    @IBOutlet weak var touchBarPopoverItem             : NSPopoverTouchBarItem!
    @IBOutlet weak var touchBarPreviewSliderItem       : NSSliderTouchBarItem!
    @IBOutlet weak var touchBarPreviewSlider           : NSSlider!
    
    private var documentObservations                   : [NSKeyValueObservation]?
    private var lastStoredMagnification                : CGFloat?
    private var _windowSubtitle                        : String?
    
    var splitController: SplitController! {
        return self.window!.contentViewController?.children.first as? SplitController
    }
    private var currentAlertSheet: NSAlert?
    var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    func showSheet(_ sheet: NSAlert?, completionHandler: ((NSApplication.ModalResponse) -> Void)?) {
        guard let window = window else { return }
        if let currentAlertSheet = currentAlertSheet {
            currentAlertSheet.window.orderOut(self)
            window.endSheet(currentAlertSheet.window)
        }
        currentAlertSheet = nil
        sheet?.beginSheetModal(for: window, completionHandler: completionHandler)
        currentAlertSheet = sheet
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        windowCount += 1
        
        NSColorPanel.shared.delegate = self
        splitController.parentTracking = self
        
        window!.title = String(format: NSLocalizedString("Untitled #%d", comment: "initializeController"), windowCount)
        window!.toolbar?.delegate = self
        window!.toolbar?.selectedItemIdentifier = annotateItem.itemIdentifier
        syncToolbarState()
        
        touchBarPreviewSlider.isEnabled = false
        ShortcutGuideWindowController.registerShortcutGuideForWindow(window!)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(productTypeDidChange(_:)),
            name: PurchaseManager.productTypeDidChangeNotification,
            object: nil
        )
    }
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = window else { preconditionFailure("window not loaded") }
        guard let newWindow = tabDelegate.addManagedWindow(windowController: WindowController.newEmptyWindow())?.window else { preconditionFailure() }
        window.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(self)
        inspectWindowHierarchy()
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if let title = window?.title {
            return title
        }
        return displayName
    }
    
    override func keyDown(with event: NSEvent) {
        // for external keyboards
        if event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting(.function)
            .isEmpty
        {
            switch event.specialKey {
            case NSEvent.SpecialKey.f1:
                openAction(event)
            case NSEvent.SpecialKey.f2:
                useAnnotateItemAction(event)
            case NSEvent.SpecialKey.f3:
                useSelectItemAction(event)
            case NSEvent.SpecialKey.f4:
                useMagnifyItemAction(event)
            case NSEvent.SpecialKey.f5:
                useMinifyItemAction(event)
            case NSEvent.SpecialKey.f6:
                useMoveItemAction(event)
            case NSEvent.SpecialKey.f7:
                fitWindowAction(event)
            case NSEvent.SpecialKey.f8:
                fillWindowAction(event)
            default:
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    private func inspectWindowHierarchy() {
        let rootWindow = window!
        print("Root window", rootWindow, rootWindow.title, "has tabs:")
        rootWindow.tabbedWindows?.forEach { window in
            print("- ", window, window.title, "isKey =", window.isKeyWindow, ", isMain =", window.isMainWindow, " at ", window.frame)
        }
    }
    
    func beginPixelMatchComparison(to image: PixelImage) {
        guard let currentPixelImage = screenshot?.image else { return }
        
        isInComparisonMode = true
        let loadingAlert = NSAlert()
        loadingAlert.messageText = NSLocalizedString("Calculating Difference...", comment: "beginPixelMatchComparison(to:)")
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "beginPixelMatchComparison(to:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        showSheet(loadingAlert, completionHandler: nil)
        
        let queue: DispatchQueue = UserDefaults.standard[.pixelMatchBackgroundMode] ?
            DispatchQueue.global(qos: .utility) : DispatchQueue.global(qos: .userInitiated)
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let maskImage = try self.pixelMatchService.performConcurrentPixelMatch(currentPixelImage.pixelImageRepresentation, image.pixelImageRepresentation)
                DispatchQueue.main.sync { [weak self] in
                    self?.splitController.beginPixelMatchComparison(to: image, with: maskImage) { [weak self] (shouldExit) in
                        if shouldExit {
                            self?.endPixelMatchComparison()
                        }
                    }
                    self?.showSheet(nil, completionHandler: nil)
                }
            } catch {
                DispatchQueue.main.sync { [weak self] in
                    let errorAlert = NSAlert(error: error)
                    self?.showSheet(errorAlert, completionHandler: { [weak self] (resp) in
                        self?.isInComparisonMode = false
                    })
                }
            }
        }
    }
    
    var shouldEndPixelMatchComparison: Bool {
        return !pixelMatchService.isProcessing && isInComparisonMode
    }
    
    func endPixelMatchComparison() {
        if shouldEndPixelMatchComparison {
            splitController.endPixelMatchComparison()
            showSheet(nil, completionHandler: nil)
            isInComparisonMode = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debugPrint("\(className):\(#function)")
    }
    
}

extension WindowController: NSToolbarItemValidation {
    
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        
        if item.action == #selector(useAnnotateItemAction(_:))
            || item.action == #selector(useSelectItemAction(_:))
            || item.action == #selector(useMagnifyItemAction(_:))
            || item.action == #selector(useMinifyItemAction(_:))
            || item.action == #selector(useMoveItemAction(_:))
            || item.action == #selector(fitWindowAction(_:))
            || item.action == #selector(fillWindowAction(_:))
            || item.action == #selector(touchBarOpenAction(_:))
            || item.action == #selector(touchBarOpenAction(_:))
            || item.action == #selector(touchBarSceneToolControlAction(_:))
            || item.action == #selector(touchBarSceneActionControlAction(_:))
        {  // when loaded
            return documentState.isLoaded
        }
        
        else if item.action == #selector(openAction(_:))
            || item.action == #selector(touchBarOpenAction(_:))
        {  // not loaded or not restricted
            return documentState.isReadable || !documentState.isLoaded
        }

        else if item.action == #selector(screenshotAction(_:))
            || item.action == #selector(touchBarScreenshotAction(_:))
        {
            return isScreenshotActionAllowed
        }

        return false
        
    }
    
}

extension WindowController {
    
    enum ToolIndex: Int {
        case magicCursor = 0
        case selectionArrow
        case magnifyingGlass
        case minifyingGlass
        case movingHand
    }

    enum ActionIndex: Int {
        case fitWindow = 0
        case fillWindow
    }
    
    private func syncToolbarState() {
        guard let identifier = window?.toolbar?.selectedItemIdentifier?.rawValue else { return }

        if identifier == SceneTool.magicCursor.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.magicCursor.rawValue
            splitController.useAnnotateItemAction(self)
        }
        else if identifier == SceneTool.selectionArrow.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.selectionArrow.rawValue
            splitController.useSelectItemAction(self)
        }
        else if identifier == SceneTool.magnifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.magnifyingGlass.rawValue
            splitController.useMagnifyItemAction(self)
        }
        else if identifier == SceneTool.minifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.minifyingGlass.rawValue
            splitController.useMinifyItemAction(self)
        }
        else if identifier == SceneTool.movingHand.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.movingHand.rawValue
            splitController.useMoveItemAction(self)
        }

        invalidateRestorableState()
    }
    
    @IBAction func touchBarOpenAction(_ sender: Any?) {
        openAction(sender)
    }
    
    @IBAction func touchBarSceneToolControlAction(_ sender: NSSegmentedControl) {
        guard documentState.isLoaded else {
            syncToolbarState()
            return
        }
        if sender.selectedSegment == ToolIndex.magicCursor.rawValue {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.selectionArrow.rawValue {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.magnifyingGlass.rawValue {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.minifyingGlass.rawValue {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.movingHand.rawValue {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        }
        syncToolbarState()
    }
    
    @IBAction func touchBarSceneActionControlAction(_ sender: NSSegmentedControl) {
        guard documentState.isLoaded else { return }
        if sender.selectedSegment == ActionIndex.fitWindow.rawValue {
            splitController.fitWindowAction(sender)
        }
        else if sender.selectedSegment == ActionIndex.fillWindow.rawValue {
            splitController.fillWindowAction(sender)
        }
    }
    
    @IBAction func touchBarScreenshotAction(_ sender: Any?) {
        screenshotAction(sender)
    }
    
}

extension WindowController: ToolbarResponder {
    
    @IBAction func openAction(_ sender: Any?) {
        guard documentState.isReadable || !documentState.isLoaded else { return }
        NSDocumentController.shared.openDocument(sender)
    }
    
    @IBAction func useAnnotateItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMagnifyItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMinifyItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useSelectItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMoveItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        syncToolbarState()
    }
    
    @IBAction func fitWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.fitWindowAction(sender)
    }
    
    @IBAction func fillWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.fillWindowAction(sender)
    }
    
    @IBAction func screenshotAction(_ sender: Any?) {
        guard documentState.isReadable || !documentState.isLoaded else { return }
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.devicesTakeScreenshotMenuItemTapped(sender)
    }
    
    @IBAction func previewSliderValueChanged(_ sender: NSSlider?) {
        guard let sender = sender else { return }
        let isPressed = !(NSEvent.pressedMouseButtons & 1 != 1)
        if isPressed {
            if previewStage == .none || previewStage == .end {
                previewStage = .begin
            } else if previewStage == .begin {
                previewStage = .inProgress
            }
        } else {
            if previewStage == .begin || previewStage == .inProgress {
                previewStage = .end
            } else if previewStage == .end {
                previewStage = .none
            }
        }
        previewAction(self, toMagnification: CGFloat(pow(2, sender.doubleValue)))
    }
    
}

extension WindowController: NSWindowDelegate {
    
    func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == self.window {
            GridWindowController.shared.activeWindowController = self
            tabDelegate.activeManagedWindow(windowController: self)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == self.window {
            ShortcutGuideWindowController.shared.hide()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == NSColorPanel.shared, let window = window as? NSColorPanel {
            window.setTarget(nil)
            window.setAction(nil)
        }
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        if let firstResponder = window.firstResponder as? UndoProxy {
            return firstResponder.undoManager
        }
        return nil
    }
    
}

extension WindowController: NSToolbarDelegate, NSTouchBarDelegate { }

extension WindowController: ScreenshotLoader {
    
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        try splitController.load(screenshot)
        
        if let fileURL = screenshot.fileURL {
            self.updateWindowTitle(fileURL)
        }
        touchBarPreviewSlider.isEnabled = true

        documentObservations = [
            observe(\.screenshot?.fileURL, options: [.new]) { (target, change) in
                if let url = change.newValue as? URL {
                    target.updateWindowTitle(url)
                }
            }
        ]
    }
    
}

extension WindowController: ItemPreviewDelegate {
    
    private var windowTitle: String {
        get { window?.title ?? ""      }
        set { window?.title = newValue }
    }

    @available(OSX 11.0, *)
    private var windowSubtitle: String {
        get { window?.subtitle ?? ""      }
        set {
            _windowSubtitle = newValue
            if PurchaseManager.shared.productType == .subscribed {
                window?.subtitle = newValue
            } else {
                window?.subtitle = NSLocalizedString("Demo Version - ", comment: "PurchaseManager") + newValue
            }
        }
    }
    
    func updateWindowTitle(_ url: URL, magnification: CGFloat? = nil) {
        let magnification = magnification ?? lastStoredMagnification ?? 1.0
        if #available(macOS 11.0, *) {
            windowTitle = url.lastPathComponent
            windowSubtitle = "\(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        } else {
            windowTitle = "\(url.lastPathComponent) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
    }
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        GridWindowController.shared.sceneRawColorDidChange(sender, at: coordinate)
    }
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sender = sender else { return }
        let restrictedMagnification = sender.wrapperRestrictedMagnification
        if restrictedMagnification != lastStoredMagnification {
            lastStoredMagnification = restrictedMagnification
            if let url = screenshot?.fileURL {
                updateWindowTitle(url, magnification: restrictedMagnification)
            }
        }
        updatePreview(to: rect, magnification: restrictedMagnification)
    }
    
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?) {
        guard let rect = rect,
            let magnification = magnification else { return }
        updatePreview(to: rect, magnification: magnification)
    }
    
    func updatePreview(to rect: CGRect, magnification: CGFloat) {
        // guard touchBarPopoverItem.popoverTouchBar.isVisible else { return }
        touchBarPreviewSlider.doubleValue = Double(log2(magnification))
    }
    
}

extension WindowController: ItemPreviewSender, ItemPreviewResponder {
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        splitController.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        splitController.previewAction(sender, atRelativePosition: position, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        splitController.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        splitController.previewAction(sender, toMagnification: magnification)
    }
    
}

extension WindowController: ShortcutGuideDataSource {

    @IBAction func toggleCommandPalette(_ sender: Any?) {
        let guideCtrl = ShortcutGuideWindowController.shared
        guideCtrl.loadItemsForWindow(window!)
        guideCtrl.toggleForWindow(window!, columnStyle: nil)
    }

    var shortcutItems: [ShortcutItem] {
        var items = [ShortcutItem]()
        if documentState.isReadable || !documentState.isLoaded {
            items += [
                ShortcutItem(
                    name: NSLocalizedString("Open...", comment: "Shortcut Guide"),
                    keyString: "F1",
                    toolTip: NSLocalizedString("Open (F1): Load a PNG image file from file system.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
            ]
        }
        if documentState.isLoaded {
            items += [
                ShortcutItem(
                    name: NSLocalizedString("Magic Cursor", comment: "Shortcut Guide"),
                    keyString: "F2",
                    toolTip: NSLocalizedString("Magic Cursor (F2): Add, or delete annotations.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Selection Arrow", comment: "Shortcut Guide"),
                    keyString: "F3",
                    toolTip: NSLocalizedString("Selection Arrow (F3): View, select, or modify annotations.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Magnifying Glass", comment: "Shortcut Guide"),
                    keyString: "F4",
                    toolTip: NSLocalizedString("Magnifying Glass (F4): Zoom in at a preset scale, supports zooming into a specified area.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Minifying Glass", comment: "Shortcut Guide"),
                    keyString: "F5",
                    toolTip: NSLocalizedString("Minifying Glass (F5): Zoom out at a preset scale.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Moving Hand", comment: "Shortcut Guide"),
                    keyString: "F6",
                    toolTip: NSLocalizedString("Moving Hand (F6): Drag to move the scene, or view the major tag of annotations.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Fit Window", comment: "Shortcut Guide"),
                    keyString: "F7",
                    toolTip: NSLocalizedString("Fit Window (F7): Scale the view to fit the window size.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Fill Window", comment: "Shortcut Guide"),
                    keyString: "F8",
                    toolTip: NSLocalizedString("Fill Window (F8): Scale the view to fill the window size.", comment: "Shortcut Guide"),
                    modifierFlags: [.function]
                ),
            ]
        }
        if isScreenshotActionAllowed {
            items += [
                ShortcutItem(
                    name: NSLocalizedString("Take Snapshot", comment: "Shortcut Guide"),
                    keyString: "S",
                    toolTip: NSLocalizedString("Take Snapshot (⌃S): Take a screenshot directly from the selected devices.", comment: "Shortcut Guide"),
                    modifierFlags: [.control]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Discover Devices", comment: "Shortcut Guide"),
                    keyString: "I",
                    toolTip: NSLocalizedString("Discover Devices (⌃I): Immediately broadcast a search for available devices on the LAN.", comment: "Shortcut Guide"),
                    modifierFlags: [.control]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Command Palette...", comment: "Shortcut Guide"),
                    keyString: NSLocalizedString("Double Press", comment: "Shortcut Guide"),
                    toolTip: NSLocalizedString("Show a palette with available keyboard shortcuts.", comment: "Shortcut Guide"),
                    modifierFlags: [.command]
                ),
            ]
        }
        return items
    }

}

extension WindowController {

    private static let restorableToolbarSelectedState = "window.toolbar.selectedItemIdentifier"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let toolbar = window?.toolbar {
            coder.encode(toolbar.selectedItemIdentifier, forKey: WindowController.restorableToolbarSelectedState)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let selectedItemIdentifier = coder.decodeObject(of: NSString.self, forKey: WindowController.restorableToolbarSelectedState)
        {
            window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: NSToolbarItem.Identifier.RawValue(selectedItemIdentifier))
            syncToolbarState()
        }
    }
    
}

extension WindowController {
    
    @objc private func productTypeDidChange(_ noti: Notification) {
        guard let manager = noti.object as? PurchaseManager else { return }
        if manager.productType == .subscribed, let lastStoredSubtitle = _windowSubtitle {
            window?.subtitle = lastStoredSubtitle
        }
    }
    
}

