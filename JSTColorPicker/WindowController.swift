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
    @IBOutlet weak var cursorItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    fileprivate var viewController: SplitController? {
        get {
            return self.window!.contentViewController as? SplitController
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        windowCount += 1
        viewController?.windowController = self
        window?.title = "Untitled #\(windowCount)"
        window?.toolbar?.selectedItemIdentifier = cursorItem.itemIdentifier
    }
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = self.window else { preconditionFailure("Expected window to be loaded") }
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

extension WindowController: ToolbarResponder {
    
    @IBAction func useCursorAction(sender: NSToolbarItem) {
        guard let viewController = viewController else { return }
        viewController.useCursorAction(sender: sender)
    }
    
    @IBAction func useMagnifyToolAction(sender: NSToolbarItem) {
        guard let viewController = viewController else { return }
        viewController.useMagnifyToolAction(sender: sender)
    }
    
    @IBAction func useMinifyToolAction(sender: NSToolbarItem) {
        guard let viewController = viewController else { return }
        viewController.useMinifyToolAction(sender: sender)
    }
    
}
