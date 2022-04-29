//
//  InfoView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/3.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@IBDesignable
final class InfoView: NSView {
    private let nibName = String(describing: InfoView.self)
    private var contentView: NSView?
    
    @IBOutlet weak var fileNameStack      : NSStackView!
    @IBOutlet weak var fileSizeStack      : NSStackView!
    @IBOutlet weak var createdAtStack     : NSStackView!
    @IBOutlet weak var modifiedAtStack    : NSStackView!
    @IBOutlet weak var snapshotAtStack    : NSStackView!
    @IBOutlet weak var dimensionStack     : NSStackView!
    @IBOutlet weak var colorSpaceStack    : NSStackView!
    @IBOutlet weak var colorProfileStack  : NSStackView!
    @IBOutlet weak var fullPathStack      : NSStackView!
    
    @IBOutlet weak var fileNameLabel      : NSTextField!
    @IBOutlet weak var fileSizeLabel      : NSTextField!
    @IBOutlet weak var createdAtLabel     : NSTextField!
    @IBOutlet weak var modifiedAtLabel    : NSTextField!
    @IBOutlet weak var snapshotAtLabel    : NSTextField!
    @IBOutlet weak var dimensionLabel     : NSTextField!
    @IBOutlet weak var colorSpaceLabel    : NSTextField!
    @IBOutlet weak var colorProfileLabel  : NSTextField!
    @IBOutlet weak var fullPathLabel      : NSTextField!
    
    private var lastStoredImageSource     : PixelImage.Source?
    private var lastStoredFileURL         : URL?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        guard let view = loadViewFromNib() else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        contentView = view
    }
    
    func loadViewFromNib() -> NSView? {
        var views: NSArray?
        guard NSNib(nibNamed: nibName, bundle: Bundle(for: type(of: self)))!.instantiate(withOwner: self, topLevelObjects: &views)
        else { return nil }
        return views?.compactMap({ $0 as? NSView }).first
    }
    
    private static var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter.init()
        return formatter
    }()

    private static var exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static var defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    func setSource(_ source: PixelImage.Source, alternativeURL url: URL? = nil) throws {
        let fileURL = url ?? source.url
        
        lastStoredImageSource = source
        lastStoredFileURL = fileURL
        
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        guard let fileProps = CGImageSourceCopyProperties(source.cgSource, nil) as? [AnyHashable: Any],
              let props = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any]
        else { throw Screenshot.Error.invalidImageProperties }
        
        var createdAtDesc: String?
        if let createdAt = attrs[.creationDate] as? Date {
            createdAtDesc = InfoView.defaultDateFormatter.string(from: createdAt)
        }
        
        var modifiedAtDesc: String?
        if let modifiedAt = attrs[.modificationDate] as? Date {
            modifiedAtDesc = InfoView.defaultDateFormatter.string(from: modifiedAt)
        }
        
        var snapshotAtDesc: String?
        if let snapshotAt = InfoView.exifDateFormatter.date(from: (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "")
        {
            snapshotAtDesc = InfoView.defaultDateFormatter.string(from: snapshotAt)
        }

        let fileSize = InfoView.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0
        
        let colorSpaceStr = props[kCGImagePropertyColorModel] as? String
        let colorProfileStr = props[kCGImagePropertyProfileName] as? String
        
        fileNameLabel.stringValue = fileURL.lastPathComponent
        fileNameStack.isHidden = false
        fileSizeLabel.stringValue = fileSize
        fileSizeStack.isHidden = false
        createdAtLabel.stringValue = createdAtDesc ?? ""
        createdAtStack.isHidden = createdAtDesc == nil
        modifiedAtLabel.stringValue = modifiedAtDesc ?? ""
        modifiedAtStack.isHidden = modifiedAtDesc == nil
        snapshotAtLabel.stringValue = snapshotAtDesc ?? ""
        snapshotAtStack.isHidden = snapshotAtDesc == nil
        dimensionLabel.stringValue = "\(pixelXDimension)×\(pixelYDimension)"
        dimensionStack.isHidden = false
        colorSpaceLabel.stringValue = colorSpaceStr ?? ""
        colorSpaceStack.isHidden = colorSpaceStr == nil
        colorProfileLabel.stringValue = colorProfileStr ?? ""
        colorProfileStack.isHidden = colorProfileStr == nil
        fullPathLabel.stringValue = fileURL.path
        fullPathStack.isHidden = false
        locateButton.isHidden = false
    }
    
    func reset() {
        [
            fileNameLabel,
            fileSizeLabel,
            createdAtLabel,
            modifiedAtLabel,
            snapshotAtLabel,
            dimensionLabel,
            colorSpaceLabel,
            colorProfileLabel,
            fullPathLabel,
        ]
        .forEach({ $0?.stringValue = "" })
        [
            fileNameStack,
            fileSizeStack,
            createdAtStack,
            modifiedAtStack,
            snapshotAtStack,
            dimensionStack,
            colorSpaceStack,
            colorProfileStack,
            fullPathStack,
        ]
        .forEach({ $0?.isHidden = true })
    }
    
    @IBOutlet weak var locateButton: NSButton!
    
    @IBAction private func locateButtonTapped(_ sender: NSButton) {
        guard let url = lastStoredFileURL else { return }
        guard url.isRegularFile else {
            presentError(GenericError.notRegularFile(url: url))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([
            url
        ])
    }
    
}
