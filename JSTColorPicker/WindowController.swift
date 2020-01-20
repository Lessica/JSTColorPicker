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
    @IBOutlet weak var screenshotItem: NSToolbarItem!
    @IBOutlet weak var cursorItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    @IBOutlet weak var fitWindowItem: NSToolbarItem!
    @IBOutlet weak var touchBarCursorItem: NSButton!
    @IBOutlet weak var touchBarMagnifyItem: NSButton!
    @IBOutlet weak var touchBarMinifyItem: NSButton!
    @IBOutlet weak var touchBarFitWindowItem: NSButton!
    
    fileprivate var viewController: SplitController? {
        get {
            return self.window!.contentViewController as? SplitController
        }
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
        viewController?.windowController = self
        window?.title = "Untitled #\(windowCount)"
        window?.toolbar?.selectedItemIdentifier = cursorItem.itemIdentifier
        touchBarUpdateButtonState()
    }
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = self.window else { preconditionFailure("Expected window to be loaded") }
        guard let tabDelegate = self.tabDelegate else { return }
        guard let newWindow = tabDelegate.addManagedWindow(windowController: WindowController.newEmptyWindow())?.window else { preconditionFailure() }
        window.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(self)
        inspectWindowHierarchy()
    }
    
    override func synchronizeWindowTitleWithDocumentName() {
        // do nothing
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if let title = window?.title {
            return title
        }
        return displayName
    }
    
    fileprivate func inspectWindowHierarchy() {
        let rootWindow = self.window!
        print("Root window", rootWindow, rootWindow.title, "has tabs:")
        rootWindow.tabbedWindows?.forEach { window in
            print("- ", window, window.title, "isKey =", window.isKeyWindow, ", isMain =", window.isMainWindow, " at ", window.frame)
        }
    }
    
    func loadDocument() {
        viewController?.loadDocument()
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
        }
        else if identifier == TrackingTool.magnify.rawValue {
            touchBarCursorItem.state = .off
            touchBarMagnifyItem.state = .on
            touchBarMinifyItem.state = .off
        }
        else if identifier == TrackingTool.minify.rawValue {
            touchBarCursorItem.state = .off
            touchBarMagnifyItem.state = .off
            touchBarMinifyItem.state = .on
        }
    }
    
    @IBAction func touchBarOpenAction(_ sender: NSButton) {
        NSDocumentController.shared.openDocument(sender)
    }
    
    @IBAction func touchBarScreenshotAction(_ sender: NSButton) {
        screenshotAction(sender)
    }
    
    @IBAction func touchBarFitWindowAction(_ sender: NSButton) {
        fitWindowAction(sender)
    }
    
    @IBAction func touchBarUseCursorAction(_ sender: NSButton) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.cursor.rawValue)
        useCursorAction(sender)
    }
    
    @IBAction func touchBarUseMagnifyAction(_ sender: NSButton) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.magnify.rawValue)
        useMagnifyToolAction(sender)
    }
    
    @IBAction func touchBarUseMinifyAction(_ sender: NSButton) {
        window?.toolbar?.selectedItemIdentifier = NSToolbarItem.Identifier(TrackingTool.minify.rawValue)
        useMinifyToolAction(sender)
    }
    
}

extension WindowController: ToolbarResponder {
    
    @IBAction func screenshotAction(_ sender: Any?) {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.screenshotItemTapped(sender)
    }
    
    @IBAction func fitWindowAction(_ sender: Any?) {
        guard let viewController = viewController else { return }
        viewController.fitWindowAction(sender)
    }
    
    @IBAction func useCursorAction(_ sender: Any?) {
        guard let viewController = viewController else { return }
        viewController.useCursorAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMagnifyToolAction(_ sender: Any?) {
        guard let viewController = viewController else { return }
        viewController.useMagnifyToolAction(sender)
        touchBarUpdateButtonState()
    }
    
    @IBAction func useMinifyToolAction(_ sender: Any?) {
        guard let viewController = viewController else { return }
        viewController.useMinifyToolAction(sender)
        touchBarUpdateButtonState()
    }
    
}

extension WindowController: NSWindowDelegate {
    
    var gridWindowController: ColorGridWindowController? {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return nil }
        let grid = delegate.colorGridController
        return grid
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        gridWindowController?.activeWindowController = self
    }
    
}

extension WindowController: SceneTracking {
    
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool {
        _ = gridWindowController?.mousePositionChanged(sender, toPoint: point)
        return true
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        gridWindowController?.sceneMagnificationChanged(sender, toMagnification: magnification)
    }
    
}

extension WindowController: ColorGridDataSource {
    
    var screenshot: Screenshot? {
        get {
            return document as? Screenshot
        }
    }
    
}
