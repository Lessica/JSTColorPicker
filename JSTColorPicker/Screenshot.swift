//
//  Screenshot.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


protocol ScreenshotLoader: class {
    var screenshot: Screenshot? { get }
    func load(_ screenshot: Screenshot) throws
}

class Screenshot: NSDocument {
    
    enum Error: LocalizedError {
        
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
                return NSLocalizedString("Invalid image.", comment: "ScreenshotError")
            case .invalidImageSource:
                return NSLocalizedString("Invalid image source.", comment: "ScreenshotError")
            case .invalidContent:
                return NSLocalizedString("Invalid content.", comment: "ScreenshotError")
            case .invalidImageType:
                return NSLocalizedString("Invalid image type.", comment: "ScreenshotError")
            case .invalidImageProperties:
                return NSLocalizedString("Invalid image properties.", comment: "ScreenshotError")
            case .cannotSerializeContent:
                return NSLocalizedString("Cannot serialize content.", comment: "ScreenshotError")
            case .cannotDeserializeContent:
                return NSLocalizedString("Cannot deserialize content.", comment: "ScreenshotError")
            case .notImplemented:
                return NSLocalizedString("This feature is not implemented.", comment: "ScreenshotError")
            }
        }
        
    }
    
    public var image: PixelImage?
    public var content: Content?
    public lazy var export: ExportManager = {
        return ExportManager(screenshot: self)
    }()
    public var isLoaded: Bool {
        return image != nil && content != nil
    }
    
    private var appDelegate: AppDelegate! {
        return NSApplication.shared.delegate as? AppDelegate
    }
    
    private var tabService: TabService? {
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
        
        let source = image.imageSource.cgSource
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            throw Error.invalidImageProperties
        }
        
        guard let EXIFDictionary = (metadata[(kCGImagePropertyExifDictionary as String)]) as? [AnyHashable: Any] else { return }
        guard let archivedContentBase64EncodedString = EXIFDictionary[(kCGImagePropertyExifUserComment as String)] as? String else { return }
        if let archivedContentData = Data(base64Encoded: archivedContentBase64EncodedString) {
            guard let archivedContent = NSKeyedUnarchiver.unarchiveObject(with: archivedContentData) as? Content else {
                throw Error.cannotDeserializeContent
            }
            self.content = archivedContent
        }
    }
    
    override func data(ofType typeName: String) throws -> Data {
        guard let source = image?.imageSource else {
            throw Error.invalidImageSource
        }
        
        guard let uti = CGImageSourceGetType(source.cgSource) else {
            throw Error.invalidImageType
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any] else {
            throw Error.invalidImageProperties
        }
        
        guard let content = content else {
            throw Error.invalidContent
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
            throw Error.cannotSerializeContent
        }
        
        // now it is allowed to unblock main thread from freezing
        unblockUserInteraction()
        
        CGImageDestinationAddImageFromSource(destination, source.cgSource, 0, (metadataAsMutable as CFDictionary?))
        CGImageDestinationFinalize(destination)
        
        return destData as Data
    }
    
    // is it safe to write png files asynchronously?
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        try windowControllers
            .compactMap({ $0 as? WindowController })
            .forEach({ try $0.load(self) })
        // FIXME: global read it again...
    }
    
    override class var autosavesInPlace   : Bool { true }
    override class var preservesVersions  : Bool { true }
    
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
                    try newWindowController.load(self)
                    if let newWindow = tabService.addManagedWindow(windowController: newWindowController)?.window {
                        currentWindow.addTabbedWindow(newWindow, ordered: .above)
                        addWindowController(newWindowController)
                    }
                }
                else {
                    // load in current tab
                    try currentWindowController.load(self)
                    addWindowController(currentWindowController)
                }
            }
            else {
                // initial window
                let windowController = appDelegate.applicationReinitializeTabService()
                try windowController.load(self)
                addWindowController(windowController)
            }
        } catch {
            debugPrint(error)
        }
    }
    
}
