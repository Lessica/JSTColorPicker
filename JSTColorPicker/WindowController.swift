//
//  WindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

fileprivate var windowCount = 0

protocol TabDelegate: class {
    func createEmptyTab(newWindowController: WindowController,
                        inWindow window: NSWindow,
                        ordered orderingMode: NSWindow.OrderingMode)
}

class WindowController: NSWindowController {
    
    static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    @IBOutlet weak var cursorItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    
    weak var tabDelegate: TabDelegate?
    
    func openDocumentIfNeeded() {
        viewController?.openDocumentIfNeeded()
    }
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = self.window else { preconditionFailure("Expected window to be loaded") }
        guard let tabDelegate = self.tabDelegate else { return }
        tabDelegate.createEmptyTab(newWindowController: WindowController.newEmptyWindow(),
                                   inWindow: window,
                                   ordered: .above)
        inspectWindowHierarchy()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        windowCount += 1
        window?.title = "Untitled #\(windowCount)"
        window?.toolbar?.selectedItemIdentifier = cursorItem.itemIdentifier
        viewController?.windowController = self
    }
    
    fileprivate func inspectWindowHierarchy() {
        let rootWindow = self.window!
        print("Root window", rootWindow, rootWindow.title, "has tabs:")
        rootWindow.tabbedWindows?.forEach { window in
            print("- ", window, window.title, "isKey =", window.isKeyWindow, ", isMain =", window.isMainWindow, " at ", window.frame)
        }
    }
    
    fileprivate var viewController: SplitController? {
        get {
            return self.window!.contentViewController as? SplitController
        }
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if let title = window?.title {
            return title
        }
        return displayName
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
