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
    
    public static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    public weak var tabDelegate: TabDelegate!
    public lazy var pixelMatchService: PixelMatchService = {
        return PixelMatchService()
    }()
    private var isInComparisonMode: Bool = false
    
    @IBOutlet weak var openItem                    : NSToolbarItem!
    @IBOutlet weak var annotateItem                : NSToolbarItem!
    @IBOutlet weak var magnifyItem                 : NSToolbarItem!
    @IBOutlet weak var minifyItem                  : NSToolbarItem!
    @IBOutlet weak var selectItem                  : NSToolbarItem!
    @IBOutlet weak var moveItem                    : NSToolbarItem!
    @IBOutlet weak var fitWindowItem               : NSToolbarItem!
    @IBOutlet weak var fillWindowItem              : NSToolbarItem!
    @IBOutlet weak var screenshotItem              : NSToolbarItem!
    
    @IBOutlet weak var touchBarOpenItem            : NSButton!
    @IBOutlet weak var touchBarSceneToolControl    : NSSegmentedControl!
    @IBOutlet weak var touchBarSceneActionControl  : NSSegmentedControl!
    @IBOutlet weak var touchBarScreenshotItem      : NSButton!
    
    private var firstResponderObservation          : NSKeyValueObservation?
    
    private var viewController: SplitController! {
        return self.window!.contentViewController?.children.first as? SplitController
    }
    private var currentAlertSheet: NSAlert?
    public var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    public func showSheet(_ sheet: NSAlert?, completionHandler: ((NSApplication.ModalResponse) -> Void)?) {
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
        viewController.trackingObject = self
        
        window!.title = String(format: NSLocalizedString("Untitled #%d", comment: "initializeController"), windowCount)
        window!.toolbar?.delegate = self
        window!.toolbar?.selectedItemIdentifier = annotateItem.itemIdentifier
        syncToolbarState()
        
        #if DEBUG
        firstResponderObservation = window?.observe(\.firstResponder, options: [.new], changeHandler: { (_, change) in
            guard let firstResponder = change.newValue as? NSResponder else { return }
            debugPrint("First Responder: \(firstResponder.className)")
        })
        #endif
        
        ShortcutGuideWindowController.registerShortcutGuideForWindow(window!)
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
    
    public func beginPixelMatchComparison(to image: PixelImage) {
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
                    self?.viewController.beginPixelMatchComparison(to: image, with: maskImage) { [weak self] (shouldExit) in
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
    
    public var shouldEndPixelMatchComparison: Bool {
        return !pixelMatchService.isProcessing && isInComparisonMode
    }
    
    public func endPixelMatchComparison() {
        if shouldEndPixelMatchComparison {
            viewController.endPixelMatchComparison()
            showSheet(nil, completionHandler: nil)
            isInComparisonMode = false
        }
    }
    
    deinit {
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
            || item.action == #selector(screenshotAction(_:))
            || item.action == #selector(touchBarScreenshotAction(_:))
        {  // not loaded or not restricted
            return documentState.isReadable || !documentState.isLoaded
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
            viewController.useAnnotateItemAction(self)
        }
        else if identifier == SceneTool.selectionArrow.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.selectionArrow.rawValue
            viewController.useSelectItemAction(self)
        }
        else if identifier == SceneTool.magnifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.magnifyingGlass.rawValue
            viewController.useMagnifyItemAction(self)
        }
        else if identifier == SceneTool.minifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.minifyingGlass.rawValue
            viewController.useMinifyItemAction(self)
        }
        else if identifier == SceneTool.movingHand.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.movingHand.rawValue
            viewController.useMoveItemAction(self)
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
            viewController.fitWindowAction(sender)
        }
        else if sender.selectedSegment == ActionIndex.fillWindow.rawValue {
            viewController.fillWindowAction(sender)
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
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMagnifyItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMinifyItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useSelectItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        syncToolbarState()
    }
    
    @IBAction func useMoveItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        syncToolbarState()
    }
    
    @IBAction func fitWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        viewController.fitWindowAction(sender)
    }
    
    @IBAction func fillWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        viewController.fillWindowAction(sender)
    }
    
    @IBAction func screenshotAction(_ sender: Any?) {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        guard documentState.isReadable || !documentState.isLoaded else { return }
        delegate.devicesTakeScreenshotMenuItemTapped(sender)
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
    
    internal var screenshot    : Screenshot? { document as? Screenshot }
    private var documentState  : Screenshot.State { screenshot?.state ?? .notLoaded }
    
    func load(_ screenshot: Screenshot) throws {
        try viewController.load(screenshot)
    }
    
}

extension WindowController: SceneTracking {
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        GridWindowController.shared.sceneRawColorDidChange(sender, at: coordinate)
    }
    
}

extension WindowController: ShortcutGuideDataSource {

    var shortcutItems: [ShortcutItem] {
        return [
            ShortcutItem(
                name: NSLocalizedString("Open...", comment: "Shortcut Guide"),
                keyString: "F1",
                toolTip: NSLocalizedString("Open (F1)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Magic Cursor", comment: "Shortcut Guide"),
                keyString: "F2",
                toolTip: NSLocalizedString("Magic Cursor (F2)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Selection Arrow", comment: "Shortcut Guide"),
                keyString: "F3",
                toolTip: NSLocalizedString("Selection Arrow (F3)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Magnifying Glass", comment: "Shortcut Guide"),
                keyString: "F4",
                toolTip: NSLocalizedString("Magnifying Glass (F4)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Minifying Glass", comment: "Shortcut Guide"),
                keyString: "F5",
                toolTip: NSLocalizedString("Minifying Glass (F5)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Moving Hand", comment: "Shortcut Guide"),
                keyString: "F6",
                toolTip: NSLocalizedString("Moving Hand (F6)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Fit Window", comment: "Shortcut Guide"),
                keyString: "F7",
                toolTip: NSLocalizedString("Fit Window (F7)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
            ShortcutItem(
                name: NSLocalizedString("Fill Window", comment: "Shortcut Guide"),
                keyString: "F8",
                toolTip: NSLocalizedString("Fill Window (F8)", comment: "Shortcut Guide"),
                modifierFlags: [.function]
            ),
        ]
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

