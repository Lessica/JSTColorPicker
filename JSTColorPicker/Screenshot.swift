//
//  Screenshot.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class Screenshot: NSDocument {
    
    var image: PixelImage?
    
    fileprivate var appDelegate: AppDelegate! {
        return NSApplication.shared.delegate as? AppDelegate
    }
    
    fileprivate var tabService: TabService? {
        get {
            return appDelegate.tabService
        }
        set {
            appDelegate.tabService = newValue
        }
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        let image = try PixelImage.init(contentsOf: url)
        self.image = image
    }
    
    override var isDocumentEdited: Bool {
        return false
    }
    
    override class var autosavesInPlace: Bool {
        return false
    }
    
    override func makeWindowControllers() {
        if
            let tabService = tabService,
            let currentWindow = tabService.firstRespondingWindow,
            let currentWindowController = currentWindow.windowController as? WindowController
        {
            if let document = currentWindowController.document as? Screenshot, let _ = document.fileURL {
                // load in new tab
                let newWindowController = WindowController.newEmptyWindow()
                addWindowController(newWindowController)
                newWindowController.loadDocument()
                if let newWindow = tabService.addManagedWindow(windowController: newWindowController)?.window {
                    currentWindow.addTabbedWindow(newWindow, ordered: .above)
                    newWindow.makeKeyAndOrderFront(self)
                }
            }
            else {
                // load in current tab
                addWindowController(currentWindowController)
                currentWindowController.loadDocument()
            }
        }
        else {
            // initial window
            let windowController = appDelegate.reinitializeTabService()
            addWindowController(windowController)
            windowController.loadDocument()
            windowController.showWindow(self)
        }
    }
    
}
