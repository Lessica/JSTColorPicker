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
    case invalidImageType
    case invalidImageProperties
    case invalidContent
    case cannotSerializeContent
    case cannotDeserializeContent
    case notImplemented
    
    var failureReason: String? {
        switch self {
        case .invalidImage:
            return "Invalid image."
        case .invalidImageSource:
            return "Invalid image source."
        case .invalidContent:
            return "Invalid content."
        case .invalidImageType:
            return "Invalid image type."
        case .invalidImageProperties:
            return "Invalid image properties."
        case .cannotSerializeContent:
            return "Cannot serialize content."
        case .cannotDeserializeContent:
            return "Cannot deserialize content."
        case .notImplemented:
            return "This feature is not implemented."
        }
    }
}

protocol ScreenshotLoader: class {
    var screenshot: Screenshot? { get }
    func initializeController()
    func load(_ screenshot: Screenshot) throws
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
        
        let source = image.imageSourceRep
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            throw ScreenshotError.invalidImageProperties
        }
        
        guard let EXIFDictionary = (metadata[(kCGImagePropertyExifDictionary as String)]) as? [AnyHashable: Any] else { return }
        guard let archivedContentBase64EncodedString = EXIFDictionary[(kCGImagePropertyExifUserComment as String)] as? String else { return }
        guard let archivedContentData = Data(base64Encoded: archivedContentBase64EncodedString) else {
            throw ScreenshotError.cannotDeserializeContent
        }
        guard let archivedContent = NSKeyedUnarchiver.unarchiveObject(with: archivedContentData) as? Content else {
            throw ScreenshotError.cannotDeserializeContent
        }
        
        self.content = archivedContent
    }
    
    override func data(ofType typeName: String) throws -> Data {
        guard let source = image?.imageSourceRep else {
            throw ScreenshotError.invalidImageSource
        }
        
        guard let uti = CGImageSourceGetType(source) else {
            throw ScreenshotError.invalidImageType
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            throw ScreenshotError.invalidImageProperties
        }
        
        guard let content = content else {
            throw ScreenshotError.invalidContent
        }
        
        let archivedData = NSKeyedArchiver.archivedData(withRootObject: content)
        var metadataAsMutable = metadata
        var EXIFDictionary = (metadataAsMutable[(kCGImagePropertyExifDictionary as String)]) as? [AnyHashable: Any]
        if !(EXIFDictionary != nil) {
            EXIFDictionary = [AnyHashable: Any]()
        }
        EXIFDictionary![(kCGImagePropertyExifUserComment as String)] = archivedData.base64EncodedString()
        metadataAsMutable[(kCGImagePropertyExifDictionary as String)] = EXIFDictionary
        
        let destData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destData as CFMutableData, uti, 1, nil) else {
            throw ScreenshotError.cannotSerializeContent
        }
        
        // now it is allowed to unblock main thread from freezing
        unblockUserInteraction()
        
        CGImageDestinationAddImageFromSource(destination, source, 0, (metadataAsMutable as CFDictionary?))
        CGImageDestinationFinalize(destination)
        
        return destData as Data
    }
    
    // it is safe to write png files asynchronously
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    // TODO: Revert to Saved
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        throw ScreenshotError.notImplemented
    }
    
    // TODO: Auto Saves in Place
    override class var autosavesInPlace: Bool {
        return false
    }
    
    // TODO: Preserves Versions
    override class var preservesVersions: Bool {
        return false
    }
    
    override func makeWindowControllers() {
        do {
            if
                let tabService = tabService,
                let currentWindow = tabService.firstRespondingWindow,
                let currentWindowController = currentWindow.windowController as? WindowController
            {
                if let document = currentWindowController.document as? Screenshot, let _ = document.fileURL {
                    // load in new tab
                    let newWindowController = WindowController.newEmptyWindow()
                    addWindowController(newWindowController)
                    try newWindowController.load(self)  // I don't know a better way to trigger a document loading when it's ready...
                    if let newWindow = tabService.addManagedWindow(windowController: newWindowController)?.window {
                        currentWindow.addTabbedWindow(newWindow, ordered: .above)
                        // too bad...
                        // it breaks "Preserves Versions" feature because macOS uses this method to generate document preview :-/
                        newWindow.makeKeyAndOrderFront(self)
                    }
                }
                else {
                    // load in current tab
                    addWindowController(currentWindowController)
                    try currentWindowController.load(self)
                }
            }
            else {
                // initial window
                let windowController = appDelegate.reinitializeTabService()
                addWindowController(windowController)
                try windowController.load(self)
                windowController.showWindow(self)
            }
        } catch let error {
            debugPrint(error)
        }
    }
    
}
