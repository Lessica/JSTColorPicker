//
//  BrowserWindowController.swift
//  JSTColorPicker
//
//  Created by Rachel on 12/6/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class BrowserWindowController : NSWindowController, NSWindowDelegate {
    
    static let shared = newController()

    private static func newController() -> BrowserWindowController {
        let windowStoryboard = NSStoryboard(name: "Browser", bundle: nil)
        let windowController = windowStoryboard.instantiateInitialController() as! BrowserWindowController
        return windowController
    }

    var isVisible: Bool { window?.isVisible ?? false }

    var viewController: BrowserViewController { contentViewController as! BrowserViewController }
    var browserController: BrowserController { viewController.browserController }
    var browser: NSBrowser { viewController.browser }

    func windowDidBecomeKey(_ notification: Notification) {
        browserController.invalidate()
    }

}
