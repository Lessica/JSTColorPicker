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
    @IBOutlet weak var imageLabel1               : NSTextField!
    @IBOutlet weak var imageLabel2               : NSTextField!
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
        imageLabel1.isHidden = false
        if let imageSource1 = imageSource, let attributedText = attributedStringValue(for: imageSource1) {
            imageLabel1.attributedStringValue = attributedText
        } else {
            imageLabel1.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel")
        }

        if let imageSource2 = altImageSource, let attributedText = attributedStringValue(for: imageSource2) {
            imageLabel2.attributedStringValue = attributedText
            imageLabel2.isHidden = false
            imageActionView.isHidden = false
        } else {
            imageLabel2.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel")
            imageLabel2.isHidden = true
            imageActionView.isHidden = true
        }
    }

    private func attributedStringValue(for source: PixelImage.Source) -> NSAttributedString? {
        guard let fileProps = CGImageSourceCopyProperties(source.cgSource, nil) as? [AnyHashable: Any] else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any] else { return nil }
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: source.url.path) else { return nil }

        var createdAtDesc: String?
        if let createdAt = attrs[.creationDate] as? Date {
            createdAtDesc = InfoController.defaultDateFormatter.string(from: createdAt)
        }
        var modifiedAtDesc: String?
        if let modifiedAt = attrs[.modificationDate] as? Date {
            modifiedAtDesc = InfoController.defaultDateFormatter.string(from: modifiedAt)
        }

        let snapshotAtStr = (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "Unknown"
        var snapshotAtDesc: String?
        if let snapshotAt = InfoController.exifDateFormatter.date(from: snapshotAtStr) {
            snapshotAtDesc = InfoController.defaultDateFormatter.string(from: snapshotAt)
        }

        let fileSize = InfoController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byClipping
        let attributedResult = NSMutableAttributedString(string: source.url.lastPathComponent, attributes: [
            NSAttributedString.Key.font: NSFont.boldSystemFont(ofSize: 11.0),
            NSAttributedString.Key.foregroundColor: NSColor.labelColor,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ])

        var additionalString = "\n"
        additionalString += String(format: "%@ - %@", NSLocalizedString("PNG Image", comment: "Information Panel"), fileSize) + "\n"
        additionalString += "\n"
        additionalString += String(format: "%@: %@", NSLocalizedString("Created At", comment: "Information Panel"), createdAtDesc ?? "Unknown") + "\n"
        additionalString += String(format: "%@: %@", NSLocalizedString("Modified At", comment: "Information Panel"), modifiedAtDesc ?? "Unknown") + "\n"
        if snapshotAtDesc != nil { additionalString += String(format: "%@: %@", NSLocalizedString("Snapshot At", comment: "Information Panel"), snapshotAtDesc ?? "Unknown") + "\n" }
        additionalString += "\n"
        additionalString += String(format: "%@: %@", NSLocalizedString("Dimensions", comment: "Information Panel"), "\(pixelXDimension)×\(pixelYDimension)") + "\n"
        additionalString += String(format: "%@: %@", NSLocalizedString("Color Space", comment: "Information Panel"), (props[kCGImagePropertyColorModel] as? String) ?? "Unknown") + "\n"
        additionalString += String(format: "%@: %@", NSLocalizedString("Color Profile", comment: "Information Panel"), (props[kCGImagePropertyProfileName] as? String) ?? "Unknown")

        attributedResult.append(NSAttributedString(string: additionalString, attributes: [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11.0),
            NSAttributedString.Key.foregroundColor: NSColor.labelColor,
            NSAttributedString.Key.paragraphStyle: paragraphStyle
        ]))

        return attributedResult
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
