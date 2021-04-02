//
//  InfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InfoController: NSViewController, PaneController {
    @objc dynamic internal weak var screenshot   : Screenshot?
    private var documentObservations             : [NSKeyValueObservation]?

    private var imageSource                      : PixelImage.Source? { screenshot?.image?.imageSource }
    private var altImageSource                   : PixelImage.Source?
    private var exitComparisonHandler            : ((Bool) -> Void)?

    @IBOutlet weak var paneBox                   : NSBox!
    @IBOutlet weak var infoView1                 : InfoView!
    @IBOutlet weak var errorLabel1               : NSTextField!
    @IBOutlet weak var infoView2                 : InfoView!
    @IBOutlet weak var errorLabel2               : NSTextField!
    @IBOutlet weak var imageActionView           : NSView!
    @IBOutlet weak var exitComparisonModeButton  : NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateInformationPanel()
    }

    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
}

extension InfoController: ScreenshotLoader {
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

    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        self.altImageSource = nil

        reloadPane()
        documentObservations = [
            observe(\.screenshot?.fileURL, options: [.new]) { [unowned self] (_, change) in
                self.updateInformationPanel()
            }
        ]
    }

    func reloadPane() {
        updateInformationPanel()
    }

    private func updateInformationPanel() {
        
        if let imageSource = imageSource {
            do {
                try renderInfoView(infoView1, with: imageSource)
                infoView1.isHidden = false
                errorLabel1.isHidden = true
            } catch {
                errorLabel1.stringValue = error.localizedDescription
                infoView1.isHidden = true
                errorLabel1.isHidden = false
            }
        } else {
            errorLabel1.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel()")
            infoView1.isHidden = true
            errorLabel1.isHidden = false
        }
        
        if let imageSource = altImageSource {
            do {
                try renderInfoView(infoView2, with: imageSource)
                infoView2.isHidden = false
                errorLabel2.isHidden = true
            } catch {
                errorLabel2.stringValue = error.localizedDescription
                infoView2.isHidden = true
                errorLabel2.isHidden = false
            }
            imageActionView.isHidden = false
        } else {
            infoView2.isHidden = true
            errorLabel2.isHidden = true
            imageActionView.isHidden = true
        }
    }
    
    private func renderInfoView(_ view: InfoView, with source: PixelImage.Source) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: source.url.path)
        guard let fileProps = CGImageSourceCopyProperties(source.cgSource, nil) as? [AnyHashable: Any],
              let props = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any]
        else { throw Screenshot.Error.invalidImageProperties }
        
        var createdAtDesc: String?
        if let createdAt = attrs[.creationDate] as? Date {
            createdAtDesc = InfoController.defaultDateFormatter.string(from: createdAt)
        }
        
        var modifiedAtDesc: String?
        if let modifiedAt = attrs[.modificationDate] as? Date {
            modifiedAtDesc = InfoController.defaultDateFormatter.string(from: modifiedAt)
        }
        
        var snapshotAtDesc: String?
        if let snapshotAt = InfoController.exifDateFormatter.date(from: (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "")
        {
            snapshotAtDesc = InfoController.defaultDateFormatter.string(from: snapshotAt)
        }

        let fileSize = InfoController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0
        
        let colorSpaceStr = props[kCGImagePropertyColorModel] as? String
        let colorProfileStr = props[kCGImagePropertyProfileName] as? String
        
        view.fileNameLabel.stringValue = source.url.lastPathComponent
        view.fileSizeLabel.stringValue = fileSize
        view.createdAtStack.isHidden = createdAtDesc == nil
        view.createdAtLabel.stringValue = createdAtDesc ?? ""
        view.modifiedAtStack.isHidden = modifiedAtDesc == nil
        view.modifiedAtLabel.stringValue = modifiedAtDesc ?? ""
        view.snapshotAtStack.isHidden = snapshotAtDesc == nil
        view.snapshotAtLabel.stringValue = snapshotAtDesc ?? ""
        view.dimensionLabel.stringValue = "\(pixelXDimension)×\(pixelYDimension)"
        view.colorSpaceStack.isHidden = colorSpaceStr == nil
        view.colorSpaceLabel.stringValue = colorSpaceStr ?? ""
        view.colorProfileStack.isHidden = colorProfileStr == nil
        view.colorProfileLabel.stringValue = colorProfileStr ?? ""
        view.fullPathLabel.stringValue = source.url.path
    }
}

extension InfoController: PixelMatchResponder {
    @IBAction func exitComparisonModeButtonTapped(_ sender: NSButton) {
        if let exitComparisonHandler = exitComparisonHandler {
            exitComparisonHandler(true)
        }
    }

    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        altImageSource = image.imageSource
        exitComparisonHandler = completionHandler
        updateInformationPanel()
    }

    func endPixelMatchComparison() {
        altImageSource = nil
        exitComparisonHandler = nil
        updateInformationPanel()
    }

    private var isInComparisonMode: Bool {
        return imageSource != nil && altImageSource != nil
    }
}
