//
//  AppDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var tabService: TabService!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        replaceTabServiceWithInitialWindow()
        // Insert code here to initialize your application
    }
    
    /// Fallback for the menu bar action when all windows are closed.
    @IBAction func newWindowForTab(_ sender: Any?) {
        if let existingWindow = tabService.mainWindow {
            tabService.createTab(newWindowController: WindowController.create(),
                                 inWindow: existingWindow,
                                 ordered: .above)
        } else {
            replaceTabServiceWithInitialWindow()
        }
    }

    private func replaceTabServiceWithInitialWindow() {
        let windowController = WindowController.create()
        windowController.showWindow(self)
        tabService = TabService(initialWindowController: windowController)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            newWindowForTab(self)
        }
        return true
    }


}

