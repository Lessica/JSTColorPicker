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
    
    static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    weak var tabDelegate: TabDelegate?
    
    @IBOutlet weak var openItem: NSToolbarItem!
    @IBOutlet weak var cursorItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    @IBOutlet weak var moveItem: NSToolbarItem!
    @IBOutlet weak var fitWindowItem: NSToolbarItem!
    @IBOutlet weak var fillWindowItem: NSToolbarItem!
    @IBOutlet weak var screenshotItem: NSToolbarItem!
    
    @IBOutlet weak var touchBarOpenItem: NSButton!
    @IBOutlet weak var touchBarCursorItem: NSButton!
    @IBOutlet weak var touchBarMagnifyItem: NSButton!
    @IBOutlet weak var touchBarMinifyItem: NSButton!
    @IBOutlet weak var touchBarMoveItem: NSButton!
    @IBOutlet weak var touchBarFitWindowItem: NSButton!
    @IBOutlet weak var touchBarFillWindowItem: NSButton!
    @IBOutlet weak var touchBarScreenshotItem: NSButton!
    
    fileprivate var viewController: SplitController! {
        return self.window!.contentViewController as? SplitController
    }
    fileprivate var currentAlertSheet: NSAlert?
    
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
        viewController.trackingObject = self
        window!.title = "Untitled #\(windowCount)"
        window!.toolbar?.selectedItemIdentifier = cursorItem.itemIdentifier
        touchBarUpdateButtonState()
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
        if event.modifierFlags.contains(.control) {
            switch event.specialKey {
            case NSEvent.SpecialKey.f1:
                touchBarOpenAction(event)
            case NSEvent.SpecialKey.f2:
                touchBarUseCursorAction(event)
            case NSEvent.SpecialKey.f3:
                touchBarUseMagnifyToolAction(event)
            case NSEvent.SpecialKey.f4:
                touchBarUseMinifyToolAction(event)
            case NSEvent.SpecialKey.f5:
                touchBarUseMoveToolAction(event)
            case NSEvent.SpecialKey.f6:
                touchBarFitWindowAction(event)
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
    
    deinit {
        debugPrint("- [WindowController deinit]")
    }
    
}

extension WindowController {
    
    fileprivate func touchBarUpdateButtonState() {
        guard let identifier = window?.toolbar?.selectedItemIdentifier?.rawValue else { return }
        if identifier == TrackingTool.cursor.rawValue {
            touchBarCursorItem.state = .on
            touchBarMagnifyItem.state = .off
            touchBarMinifyItem.state = .off
            touchBarMoveItem.state = .off
        }
        else if identifier == TrackingTool.magnify.rawValue {
            touchBarCursorItem.state = .off
            touchBarMagnifyItem.state = .on
            touchBarMinifyItem.state = .off
            touchBarMoveItem.state = .off
        }
        else if identifier == TrackingTool.minify.rawValue {
            touchBarCursorItem.state = .off
            touchBarMagnifyItem.state = .off
            touchBarMinifyItem.state = .on
            touchBarMoveItem.state = .off
        }
        else if identifier == TrackingTool.move.rawValue {
            touchBarCursorItem.state = .off
            touchBarMagnifyItem.state = .off
            touchBarMinifyItem.state = .off
            touchBarMoveItem.state = .on
        }
    }
    
    @IBAction func touchBarOpenAction(_ sender: Any?) {
        openAction(sender)
    }
    
    @IBAction func touchBarUseCursorAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.cursor.rawValue)
        useCursorAction(sender)
    }
    
    @IBAction func touchBarUseMagnifyToolAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.magnify.rawValue)
        useMagnifyToolAction(sender)
    }
    
    @IBAction func touchBarUseMinifyToolAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.minify.rawValue)
        useMinifyToolAction(sender)
    }
    
    @IBAction func touchBarUseMoveToolAction(_ sender: Any?) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.move.rawValue)
        useMoveToolAction(sender)
    }
    
    @IBAction func touchBarFitWindowAction(_ sender: Any?) {
        fitWindowAction(sender)
    }
    
    @IBAction func touchBarFillWindowAction(_ sender: Any?) {
        fillWindowAction(sender)
    }
    
    @IBAction func touchBarScreenshotAction(_ sender: Any?) {
        screenshotAction(sender)
    }
    
}

extension WindowController: ToolbarResponder {
    
    @IBAction func openAction(_ sender: Any?) {
        NSDocumentController.shared.openDocument(sender)
    }
    
    @IBAction func useCursorAction(_ sender: Any?) {
        viewController.useCursorAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMagnifyToolAction(_ sender: Any?) {
        viewController.useMagnifyToolAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMinifyToolAction(_ sender: Any?) {
        viewController.useMinifyToolAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMoveToolAction(_ sender: Any?) {
        viewController.useMoveToolAction(sender)
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
        delegate.screenshotItemTapped(sender)
    }
    
}

extension WindowController: NSWindowDelegate {
    
    fileprivate var gridWindowController: ColorGridWindowController? {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return nil }
        let grid = delegate.colorGridController
        return grid
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        gridWindowController?.activeWindowController = self
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        return screenshot?.undoManager
    }
    
}

extension WindowController: ScreenshotLoader {
    
    internal var screenshot: Screenshot? {
        return document as? Screenshot
    }
    
    func resetController() {
        
    }
    
    func load(_ screenshot: Screenshot) throws {
        try viewController.load(screenshot)
    }
    
}

extension WindowController: SceneTracking {
    
    func trackCursorPositionChanged(_ sender: Any, to coordinate: PixelCoordinate) {
        gridWindowController?.trackCursorPositionChanged(sender, to: coordinate)
    }
    
}
