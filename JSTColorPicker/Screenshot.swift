//
//  Screenshot.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum ScreenshotError: LocalizedError {
    case invalidImage
    case invalidImageSource
    case invalidContent
    
    var failureReason: String? {
        switch self {
        case .invalidImage:
            return "Invalid image."
        case .invalidImageSource:
            return "Invalid image source."
        case .invalidContent:
            return "Invalid content."
        }
    }
}

protocol ScreenshotLoader: class {
    var screenshot: Screenshot? { get }
    func resetController()
    func load(screenshot: Screenshot) throws
}

class Screenshot: NSDocument {
    
    var image: PixelImage?
    var content: Content?
    
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
        self.content = Content()
    }
    
    override var isDocumentEdited: Bool {
        return false
    }
    
    override var hasUndoManager: Bool {
        get {
            return true
        }
        set {
            super.hasUndoManager = newValue
        }
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
                do {
                    try newWindowController.load(screenshot: self)
                } catch let error {
                    debugPrint(error)
                }
                if let newWindow = tabService.addManagedWindow(windowController: newWindowController)?.window {
                    currentWindow.addTabbedWindow(newWindow, ordered: .above)
                    newWindow.makeKeyAndOrderFront(self)
                }
            }
            else {
                // load in current tab
                addWindowController(currentWindowController)
                do {
                    try currentWindowController.load(screenshot: self)
                } catch let error {
                    debugPrint(error)
                }
            }
        }
        else {
            // initial window
            let windowController = appDelegate.reinitializeTabService()
            addWindowController(windowController)
            do {
                try windowController.load(screenshot: self)
            } catch let error {
                debugPrint(error)
            }
            windowController.showWindow(self)
        }
    }
    
}
