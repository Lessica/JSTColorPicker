//
//  Screenshot.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class Screenshot: NSDocument {
    
    fileprivate var appDelegate: AppDelegate? {
        get {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                return appDelegate
            }
            return nil
        }
    }
    
    fileprivate var tabService: TabService? {
        get {
            return appDelegate?.tabService
        }
        set {
            appDelegate?.tabService = newValue
        }
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        
    }
    
    override class var autosavesInPlace: Bool {
        return true 
    }
    
    override func makeWindowControllers() {
        if
            let tabService = tabService,
            let currentWindow = tabService.mainWindow,
            let windowController = currentWindow.windowController as? WindowController
        {
            if currentWindow.windowController?.document == nil {
                // load in current tab
                addWindowController(windowController)
                windowController.openDocumentIfNeeded()
            }
            else {
                // load in new tab
                let windowController = WindowController.newEmptyWindow()
                tabService.createEmptyTab(newWindowController: windowController,
                                          inWindow: currentWindow,
                                          ordered: .above)
                addWindowController(windowController)
                windowController.openDocumentIfNeeded()
            }
        }
        else {
            // initial window
            if let windowController = appDelegate?.reinitializeTabService() {
                addWindowController(windowController)
                windowController.openDocumentIfNeeded()
            }
        }
    }
    
}
