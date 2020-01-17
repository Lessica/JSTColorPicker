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
    
    var tabService: TabService?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        _ = reinitializeTabService()
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func reinitializeTabService() -> WindowController {
        let windowController = WindowController.newEmptyWindow()
        windowController.showWindow(self)
        tabService = TabService(initialWindowController: windowController)
        return windowController
    }
    
    @IBAction func showGithubPage(_ sender: NSMenuItem) {
        if let url = URL.init(string: "https://github.com/Lessica/JSTColorPicker") {
            NSWorkspace.shared.open(url)
        }
    }
    
}

