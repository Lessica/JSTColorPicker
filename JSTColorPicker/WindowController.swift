//
//  WindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

fileprivate var windowCount = 0

class WindowController: NSWindowController {
    
    public static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    public weak var tabDelegate: TabDelegate?
    public lazy var pixelMatchService: PixelMatchService = {
        return PixelMatchService()
    }()
    fileprivate var isInComparisonMode: Bool = false
    
    @IBOutlet weak var openItem: NSToolbarItem!
    @IBOutlet weak var annotateItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    @IBOutlet weak var selectItem: NSToolbarItem!
    @IBOutlet weak var moveItem: NSToolbarItem!
    @IBOutlet weak var fitWindowItem: NSToolbarItem!
    @IBOutlet weak var fillWindowItem: NSToolbarItem!
    @IBOutlet weak var screenshotItem: NSToolbarItem!
    
    @IBOutlet weak var touchBarOpenItem: NSButton!    
    @IBOutlet weak var touchBarSceneToolControl: NSSegmentedControl!
    @IBOutlet weak var touchBarSceneActionControl: NSSegmentedControl!
    @IBOutlet weak var touchBarScreenshotItem: NSButton!
    
    fileprivate var viewController: SplitController! {
        return self.window!.contentViewController as? SplitController
    }
    fileprivate var currentAlertSheet: NSAlert?
    
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
        viewController.trackingObject = self
        initializeController()
    }
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = window else { preconditionFailure("window not loaded") }
        guard let tabDelegate = self.tabDelegate else { return }
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
        // for windows keyboards
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.function, .control] {
            switch event.specialKey {
            case NSEvent.SpecialKey.f1:
                touchBarOpenAction(event)
            case NSEvent.SpecialKey.f2:
                touchBarUseAnnotateItemAction(event)
            case NSEvent.SpecialKey.f3:
                touchBarUseMagnifyItemAction(event)
            case NSEvent.SpecialKey.f4:
                touchBarUseMinifyItemAction(event)
            case NSEvent.SpecialKey.f5:
                touchBarUseSelectItemAction(event)
            case NSEvent.SpecialKey.f6:
                touchBarUseMoveItemAction(event)
            case NSEvent.SpecialKey.f7:
                touchBarFitWindowAction(event)
            case NSEvent.SpecialKey.f8:
                touchBarFillWindowAction(event)
            default:
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    fileprivate func inspectWindowHierarchy() {
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
            } catch let error {
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
        debugPrint("- [WindowController deinit]")
    }
    
}

extension WindowController {
    
    fileprivate func touchBarUpdateButtonState() {
        guard let identifier = window?.toolbar?.selectedItemIdentifier?.rawValue else { return }
        if identifier == SceneTool.magicCursor.rawValue {
            touchBarSceneToolControl.selectedSegment = 0
        }
        else if identifier == SceneTool.magnifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = 1
        }
        else if identifier == SceneTool.minifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = 2
        }
        else if identifier == SceneTool.selectionArrow.rawValue {
            touchBarSceneToolControl.selectedSegment = 3
        }
        else if identifier == SceneTool.movingHand.rawValue {
            touchBarSceneToolControl.selectedSegment = 4
        }
    }
    
    @IBAction func touchBarOpenAction(_ sender: Any?) {
        openAction(sender)
    }
    
    fileprivate func touchBarUseAnnotateItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        useAnnotateItemAction(sender)
    }
    
    fileprivate func touchBarUseMagnifyItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        useMagnifyItemAction(sender)
    }
    
    fileprivate func touchBarUseMinifyItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        useMinifyItemAction(sender)
    }
    
    fileprivate func touchBarUseSelectItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        useSelectItemAction(sender)
    }
    
    fileprivate func touchBarUseMoveItemAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        useMoveItemAction(sender)
    }
    
    @IBAction func touchBarSceneToolControlAction(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            touchBarUseAnnotateItemAction(sender)
        }
        else if sender.selectedSegment == 1 {
            touchBarUseMagnifyItemAction(sender)
        }
        else if sender.selectedSegment == 2 {
            touchBarUseMinifyItemAction(sender)
        }
        else if sender.selectedSegment == 3 {
            touchBarUseSelectItemAction(sender)
        }
        else if sender.selectedSegment == 4 {
            touchBarUseMoveItemAction(sender)
        }
    }
    
    fileprivate func touchBarFitWindowAction(_ sender: Any?) {
        fitWindowAction(sender)
    }
    
    fileprivate func touchBarFillWindowAction(_ sender: Any?) {
        fillWindowAction(sender)
    }
    
    @IBAction func touchBarSceneActionControlAction(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 {
            touchBarFitWindowAction(sender)
        }
        else if sender.selectedSegment == 1 {
            touchBarFillWindowAction(sender)
        }
    }
    
    @IBAction func touchBarScreenshotAction(_ sender: Any?) {
        screenshotAction(sender)
    }
    
}

extension WindowController: ToolbarResponder {
    
    @IBAction func openAction(_ sender: Any?) {
        NSDocumentController.shared.openDocument(sender)
    }
    
    @IBAction func useAnnotateItemAction(_ sender: Any?) {
        viewController.useAnnotateItemAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMagnifyItemAction(_ sender: Any?) {
        viewController.useMagnifyItemAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMinifyItemAction(_ sender: Any?) {
        viewController.useMinifyItemAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useSelectItemAction(_ sender: Any?) {
        viewController.useSelectItemAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMoveItemAction(_ sender: Any?) {
        viewController.useMoveItemAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func fitWindowAction(_ sender: Any?) {
        guard (document?.fileURL) != nil else { return }
        viewController.fitWindowAction(sender)
    }
    
    @IBAction func fillWindowAction(_ sender: Any?) {
        guard (document?.fileURL) != nil else { return }
        viewController.fillWindowAction(sender)
    }
    
    @IBAction func screenshotAction(_ sender: Any?) {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.screenshotMenuItemTapped(sender)
    }
    
}

extension WindowController: NSWindowDelegate {
    
    fileprivate var gridWindowController: GridWindowController? {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return nil }
        let grid = delegate.gridController
        return grid
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        gridWindowController?.activeWindowController = self
        tabDelegate?.activeManagedWindow(windowController: self)
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return screenshot?.undoManager
    }
    
}

extension WindowController: ScreenshotLoader {
    
    internal var screenshot: Screenshot? {
        return document as? Screenshot
    }
    
    func initializeController() {
        window!.title = String(format: NSLocalizedString("Untitled #%d", comment: "initializeController"), windowCount)
        window!.toolbar?.selectedItemIdentifier = annotateItem.itemIdentifier
        touchBarUpdateButtonState()
    }
    
    func load(_ screenshot: Screenshot) throws {
        try viewController.load(screenshot)
    }
    
}

extension WindowController: SceneTracking {
    
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        gridWindowController?.trackColorChanged(sender, at: coordinate)
    }
    
}
