//
//  Screenshot.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


protocol ScreenshotLoader: AnyObject {
    var screenshot: Screenshot? { get }
    func load(_ screenshot: Screenshot) throws
}

final class Screenshot: NSDocument {
    
    // MARK: - Types
    
    enum Error: CustomNSError, LocalizedError {
        case invalidImage
        case invalidImageSource
        case invalidImageType
        case invalidImageProperties
        case invalidContent
        case cannotSerializeContent
        case cannotDeserializeContent
        case notImplemented
        #if APP_STORE
        case platformSubscriptionRequired
        #endif
        
        var errorCode: Int {
            switch self {
            case .invalidImage:
                return 301
            case .invalidImageSource:
                return 302
            case .invalidContent:
                return 303
            case .invalidImageType:
                return 304
            case .invalidImageProperties:
                return 305
            case .cannotSerializeContent:
                return 306
            case .cannotDeserializeContent:
                return 307
            case .notImplemented:
                return 308
            #if APP_STORE
            case .platformSubscriptionRequired:
                return 309
            #endif
            }
        }
        
        var failureReason: String? {
            switch self {
            case .invalidImage:
                return NSLocalizedString("Invalid image.", comment: "Screenshot.Error")
            case .invalidImageSource:
                return NSLocalizedString("Invalid image source.", comment: "Screenshot.Error")
            case .invalidContent:
                return NSLocalizedString("Invalid content.", comment: "Screenshot.Error")
            case .invalidImageType:
                return NSLocalizedString("Invalid image type.", comment: "Screenshot.Error")
            case .invalidImageProperties:
                return NSLocalizedString("Invalid image properties.", comment: "Screenshot.Error")
            case .cannotSerializeContent:
                return NSLocalizedString("Cannot serialize content.", comment: "Screenshot.Error")
            case .cannotDeserializeContent:
                return NSLocalizedString("Cannot deserialize content.", comment: "Screenshot.Error")
            case .notImplemented:
                return NSLocalizedString("This feature is not implemented.", comment: "Screenshot.Error")
            #if APP_STORE
            case .platformSubscriptionRequired:
                return NSLocalizedString("This operation requires valid subscription of JSTColorPicker.", comment: "Screenshot.Error")
            #endif
            }
        }
    }
    
    enum State {
        case notLoaded
        case restricted
        case readable
        case writeable
        
        var isLoaded   : Bool { self != .notLoaded                      }
        var isReadable : Bool { self == .readable || self == .writeable }
        var isWritable: Bool { self == .writeable                      }
    }
    
    
    // MARK: - Attributes
    
    public fileprivate(set) var image            : PixelImage?
    public fileprivate(set) var metadata         : [AnyHashable: Any]?
    public fileprivate(set) var content          : Content?
    private var decodedMetadata                  : [AnyHashable: Any]?
    public lazy var viewableMetadata             : [AnyHashable: Any]? = {
        guard var DecodedMetadata = decodedMetadata else { return nil }
        guard var EXIFDictionary = (DecodedMetadata[(kCGImagePropertyExifDictionary as String)]) as? [AnyHashable: Any] else { return nil }
        guard let UserCommentData = EXIFDictionary[(kCGImagePropertyExifUserComment as String)] as? Data else { return nil }
        guard let UnarchivedContent = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(UserCommentData) as? Content else { return nil }
        guard let EncodedContentData = try? PropertyListEncoder().encode(UnarchivedContent) else { return nil }
        guard let DecodedContentObject = try? PropertyListSerialization.propertyList(from: EncodedContentData, options: [], format: nil) else { return nil }
        EXIFDictionary[(kCGImagePropertyExifUserComment as String)] = DecodedContentObject as? [AnyHashable: Any]
        DecodedMetadata[(kCGImagePropertyExifDictionary as String)] = EXIFDictionary
        return DecodedMetadata
    }()
    
    public var state         : State
    {
        if content == nil || image == nil       { return .notLoaded  }
        else if isInViewingMode                 { return .restricted }
        else if isLocked                        { return .readable   }
        return .writeable
    }
    
    
    // MARK: - Read & Write
    
    override func read(from url: URL, ofType typeName: String) throws {
        let image = try PixelImage.init(contentsOf: url)
        self.image = image
        self.content = Content()
        
        let source = image.imageSource.cgSource
        guard let uti = CGImageSourceGetType(source), Screenshot.readableTypes.contains(uti as String) else {
            throw Error.invalidImageType
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            throw Error.invalidImageProperties
        }
        
        var viewableMetadata = metadata
        self.metadata = metadata

        guard var EXIFDictionary = (metadata[(kCGImagePropertyExifDictionary as String)]) as? [AnyHashable: Any] else { return }
        guard let archivedContentBase64EncodedString = EXIFDictionary[(kCGImagePropertyExifUserComment as String)] as? String else { return }
        if let unarchivedContentData = Data(base64Encoded: archivedContentBase64EncodedString) {
            EXIFDictionary[(kCGImagePropertyExifUserComment as String)] = unarchivedContentData
            guard let archivedContent = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(unarchivedContentData) as? Content else {
                throw Error.cannotDeserializeContent
            }
            viewableMetadata[(kCGImagePropertyExifDictionary as String)] = EXIFDictionary
            self.content = archivedContent
            self.decodedMetadata = viewableMetadata
        }
    }
    
    override class var readableTypes: [String] {
        [
            "public.png",
            "public.jpeg"
        ]
    }
    
    override class var writableTypes: [String] {
        [
            "public.png",
            "public.jpeg",
        ]
    }
    
    override func fileNameExtension(forType typeName: String, saveOperation: NSDocument.SaveOperationType) -> String? {
        if typeName == "public.png" {
            return "png"
        } else if typeName == "public.jpeg" {
            return "jpg"
        }
        return nil
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        let restrictedOperation: [NSDocument.SaveOperationType] = [
            .saveOperation,
            .autosaveInPlaceOperation,
        ]
        if restrictedOperation.contains(saveOperation) {
            try testExportCondition()
        }
        try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
    }
    
    override func data(ofType typeName: String) throws -> Data {
        guard let source = image?.imageSource else {
            throw Error.invalidImageSource
        }
        
        guard let uti = CGImageSourceGetType(source.cgSource), Screenshot.writableTypes.contains(uti as String) else {
            throw Error.invalidImageType
        }
        
        guard let metadata = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any] else {
            throw Error.invalidImageProperties
        }
        
        guard let content = content else {
            throw Error.invalidContent
        }
        
        let archivedData = try NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: true)
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
    
    // is it safe to read png files asynchronously?
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    // is it safe to write png files asynchronously?
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    @objc dynamic override var fileURL: URL? {
        willSet {
            guard let image = image, let url = newValue else { return }
            image.rename(to: url)
        }
    }
    
    override class var autosavesInPlace   : Bool { true }
    override class var autosavesDrafts    : Bool { true }
    override class var preservesVersions  : Bool { true }
    

#if WITH_COCOA
    // MARK: - Controllers

    private var appDelegate  : AppDelegate! { AppDelegate.shared }
    private var tabService   : TabService?
    {
        get { appDelegate.tabService            }
        set { appDelegate.tabService = newValue }
    }

    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        try windowControllers
            .compactMap({ $0 as? WindowController })
            .forEach({ try $0.load(self) })
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
                let windowController = appDelegate.reinitializeTabService()
                try windowController.load(self)
                addWindowController(windowController)
            }
        } catch {
            debugPrint(error)
        }
    }
    

    // MARK: - Content Extraction

    public lazy var export   : ExportManager = { return ExportManager(screenshot: self) }()
    public func testExportCondition() throws {
        #if APP_STORE
        guard PurchaseManager.shared.getProductType() == .subscribed
        else {
            throw Error.platformSubscriptionRequired
        }
        #endif
    }
    private(set) var isExtractingContentItems: Bool = false

    func extractContentItems(
        in window: NSWindow,
        with template: Template,
        asyncTask task: @escaping (Template) throws -> Void,
        completionHandler completion: ((Bool) -> Void)? = nil
    ) {
        guard !isExtractingContentItems else {
            fatalError("now extracting content items")
        }
        self.isExtractingContentItems = true
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "copy(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.messageText = NSLocalizedString("Extract Snippets", comment: "copy(_:)")
        loadingAlert.informativeText = String(format: NSLocalizedString("Extract code snippets from template \"%@\"…", comment: "copy(_:)"), template.name)
        loadingAlert.beginSheetModal(for: window) { (resp) in }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                defer {
                    DispatchQueue.main.async { [weak self] in
                        loadingAlert.window.orderOut(self)
                        window.endSheet(loadingAlert.window)
                        self?.isExtractingContentItems = false
                        completion?(true)
                    }
                }
                try task(template)
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.presentError(error)
                    self?.isExtractingContentItems = false
                    completion?(false)
                }
            }
        }
    }
#else
    public func testExportCondition() throws {}
#endif
}
