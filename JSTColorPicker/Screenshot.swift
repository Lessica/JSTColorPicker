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
    
    enum State {
        case notLoaded
        case restricted
        case readable
        case writeable
        
        var isLoaded   : Bool { self != .notLoaded                      }
        var isReadable : Bool { self == .readable || self == .writeable }
        var isWriteable: Bool { self == .writeable                      }
    }
    
    public fileprivate(set) var image    : PixelImage?
    public fileprivate(set) var content  : Content?
    public lazy var export               : ExportManager = { return ExportManager(screenshot: self) }()
    public var state                    : State
    {
        if content == nil || image == nil       { return .notLoaded  }
        else if isInViewingMode                 { return .restricted }
        else if isLocked                        { return .readable   }
        return .writeable
    }
    
    private var appDelegate  : AppDelegate! { AppDelegate.shared }
    private var tabService   : TabService?
    {
        get { appDelegate.tabService            }
        set { appDelegate.tabService = newValue }
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
            guard let archivedContent = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archivedContentData) as? Content else {
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
    
    // is it safe to write png files asynchronously?
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        try windowControllers
            .compactMap({ $0 as? WindowController })
            .forEach({ try $0.load(self) })
    }
    
    @objc dynamic override var fileURL: URL? {
        willSet {
            guard let image = image, let url = newValue else { return }
            image.rename(to: url)
        }
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
                let windowController = appDelegate.reinitializeTabService()
                try windowController.load(self)
                addWindowController(windowController)
            }
        } catch {
            debugPrint(error)
        }
    }
    
}

extension Screenshot {
    
    private var associatedWindowController: WindowController? { windowControllers.first as? WindowController }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copyAll(_:))
            || menuItem.action == #selector(exportAll(_:))
        {
            guard let template = ExportManager.selectedTemplate else { return false }

            if menuItem.action == #selector(exportAll(_:)) {
                guard template.saveInPlace || template.allowedExtensions.count > 0 else { return false }
            }
        }
        return super.validateMenuItem(menuItem)
    }
    
    @IBAction func copyAll(_ sender: Any) {
        guard let template = ExportManager.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }
        
        if template.isAsync {
            copyAllContentItemsAsync(with: template)
        } else {
            copyAllContentItems(with: template)
        }
    }
    
    @IBAction func exportAll(_ sender: Any) {
        guard let window = associatedWindowController?.window else { return }
        guard let template = ExportManager.selectedTemplate else {
            presentError(ExportManager.Error.noTemplateSelected)
            return
        }
        guard template.saveInPlace || template.allowedExtensions.count > 0 else {
            presentError(ExportManager.Error.noExtensionSpecified)
            return
        }

        if !template.saveInPlace {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = String(format: NSLocalizedString("%@ Exported %ld Items", comment: "exportAll(_:)"), displayName ?? "", content?.items.count ?? 0)
            panel.allowedFileTypes = template.allowedExtensions
            panel.beginSheetModal(for: window) { [unowned self] (resp) in
                if resp == .OK {
                    if let url = panel.url {
                        if template.isAsync {
                            self.exportAllContentItemsAsync(to: url, with: template)
                        } else {
                            self.exportAllContentItems(to: url, with: template)
                        }
                    }
                }
            }
        } else {
            if template.isAsync {
                self.exportAllContentItemsAsyncInPlace(with: template)
            } else {
                self.exportAllContentItemsInPlace(with: template)
            }
        }
    }
    
    private func copyAllContentItems(with template: Template) {
        do {
            try export.copyAllContentItems(with: template)
        } catch {
            presentError(error)
        }
    }

    private func copyAllContentItemsAsync(with template: Template) {
        extractAllContentItemsAsync(with: template) { [unowned self] (tmpl) in
            try export.copyAllContentItems(with: tmpl)
        }
    }
    
    private func exportAllContentItems(to url: URL, with template: Template) {
        do {
            try export.exportAllContentItems(to: url, with: template)
        } catch {
            presentError(error)
        }
    }

    private func exportAllContentItemsInPlace(with template: Template) {
        do {
            try export.exportAllContentItemsInPlace(with: template)
        } catch {
            presentError(error)
        }
    }

    private func exportAllContentItemsAsync(to url: URL, with template: Template) {
        extractAllContentItemsAsync(with: template) { [unowned self] (tmpl) in
            try self.export.exportAllContentItems(to: url, with: tmpl)
        }
    }

    private func exportAllContentItemsAsyncInPlace(with template: Template) {
        extractAllContentItemsAsync(with: template) { [unowned self] (tmpl) in
            try self.export.exportAllContentItemsInPlace(with: tmpl)
        }
    }

    private func extractAllContentItemsAsync(with template: Template, completionHandler completion: @escaping (Template) throws -> Void) {
        guard let window = associatedWindowController?.window else { return }
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "copy(_:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.messageText = NSLocalizedString("Extract Snippets", comment: "copy(_:)")
        loadingAlert.informativeText = String(format: NSLocalizedString("Extract code snippets from template \"%@\"...", comment: "copy(_:)"), template.name)
        loadingAlert.beginSheetModal(for: window) { (resp) in }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            do {
                defer {
                    DispatchQueue.main.async {
                        loadingAlert.window.orderOut(self)
                        window.endSheet(loadingAlert.window)
                    }
                }
                try completion(template)
            } catch {
                DispatchQueue.main.async { [unowned self] in
                    self.presentError(error)
                }
            }
        }
    }
    
}

extension Screenshot {

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
    }

}
