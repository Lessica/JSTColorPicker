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
    func createTab(newWindowController: WindowController,
                   inWindow window: NSWindow,
                   ordered orderingMode: NSWindow.OrderingMode)
}

class WindowController: NSWindowController {
    
    @IBOutlet weak var openItem: NSToolbarItem!
    @IBOutlet weak var cursorItem: NSToolbarItem!
    @IBOutlet weak var magnifyItem: NSToolbarItem!
    @IBOutlet weak var minifyItem: NSToolbarItem!
    
    static func create() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        windowCount += 1
        self.window?.title = "Untitled #\(windowCount)"
        self.window?.toolbar?.selectedItemIdentifier = cursorItem.itemIdentifier
    }
    
    weak var tabDelegate: TabDelegate?
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = self.window else { preconditionFailure("Expected window to be loaded") }
        guard let tabDelegate = self.tabDelegate else { return }
        tabDelegate.createTab(newWindowController: WindowController.create(),
                              inWindow: window,
                              ordered: .above)
        inspectWindowHierarchy()
    }
    
    func inspectWindowHierarchy() {
        let rootWindow = self.window!
        print("Root window", rootWindow, rootWindow.title, "has tabs:")
        rootWindow.tabbedWindows?.forEach { window in
            print("- ", window, window.title, "isKey =", window.isKeyWindow, ", isMain =", window.isMainWindow, " at ", window.frame)
        }
    }
    
    var viewController: SplitController? {
        get {
            return self.window!.contentViewController as? SplitController
        }
    }
    
}

extension WindowController {
    
    @IBAction func loadImageAction(sender: NSToolbarItem) {
        guard let viewController = viewController else { return }
        viewController.loadImageAction(sender: sender)
    }
    
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
