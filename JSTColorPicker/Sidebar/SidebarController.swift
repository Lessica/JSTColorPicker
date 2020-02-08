//
//  SidebarController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let newLength = self.count
        if newLength < toLength {
            return String(repeatElement(character, count: toLength - newLength)) + self
        } else {
            let idx = self.index(self.startIndex, offsetBy: newLength - toLength)
            return String(self[..<idx])
        }
    }
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
}

class SidebarController: NSViewController {
    
    internal weak var screenshot: Screenshot?
    
    @IBOutlet weak var imageLabel: NSTextField!
    @IBOutlet weak var inspectorColorLabel: NSTextField!
    @IBOutlet weak var inspectorColorFlag: ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel: NSTextField!
    
    @IBOutlet weak var previewImageView: PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    @IBOutlet weak var previewSlider: PreviewSlider!
    @IBOutlet weak var previewSliderLabel: NSTextField!
    weak var previewOverlayDelegate: PreviewResponder?
    
    fileprivate let colorPanel = NSColorPanel.shared
    fileprivate static var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter.init()
        return formatter
    }()
    fileprivate static var exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    fileprivate static var defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        previewOverlayView.overlayDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetController()
    }
    
    func updateItemInspector(for item: ContentItem, submit: Bool) {
        if let color = item as? PixelColor {
            inspectorColorLabel.stringValue = """
R:\(String(color.red).leftPadding(toLength: 5, withPad: " "))\(String(format: "0x%02X", color.red).leftPadding(toLength: 7, withPad: " "))
G:\(String(color.green).leftPadding(toLength: 5, withPad: " "))\(String(format: "0x%02X", color.green).leftPadding(toLength: 7, withPad: " "))
B:\(String(color.blue).leftPadding(toLength: 5, withPad: " "))\(String(format: "0x%02X", color.blue).leftPadding(toLength: 7, withPad: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(toLength: 5, withPad: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(toLength: 6, withPad: " "))
"""
            let nsColor = color.toNSColor()
            inspectorColorFlag.color = nsColor
            inspectorColorFlag.image = NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size)
            inspectorAreaLabel.stringValue = """
CSS:\(color.cssString.leftPadding(toLength: 10, withPad: " "))
\(color.coordinate.description.leftPadding(toLength: 14, withPad: " "))
"""
            if submit {
                colorPanel.color = nsColor
            }
        }
        else if let area = item as? PixelArea {
            inspectorAreaLabel.stringValue = """
W:\(String(area.rect.width).leftPadding(toLength: 12, withPad: " "))
H:\(String(area.rect.height).leftPadding(toLength: 12, withPad: " "))
"""
        }
    }
    
    func updatePreview(to rect: CGRect, magnification: CGFloat) {
        if let imageSize = screenshot?.image?.size {
            let previewRect = CGRect(origin: .zero, size: imageSize.toCGSize()).aspectFit(in: previewImageView.bounds)
            let previewScale = min(previewRect.width / CGFloat(imageSize.width), previewRect.height / CGFloat(imageSize.height))
            let highlightRect = CGRect(x: previewRect.minX + rect.minX * previewScale, y: previewRect.minY + rect.minY * previewScale, width: rect.width * previewScale, height: rect.height * previewScale)
            previewOverlayView.highlightArea = highlightRect
        }
        
        previewSliderLabel.stringValue = "\(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        previewSlider.doubleValue = Double(log2(magnification))
    }
    
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?) {
        guard let rect = rect, let magnification = magnification else { return }
        updatePreview(to: rect, magnification: magnification)
    }
    
    deinit {
        debugPrint("- [SidebarController deinit]")
    }
    
    @IBAction func colorIndicatorTapped(_ sender: Any) {
        colorPanel.mode = .RGB
        colorPanel.showsAlpha = true
        colorPanel.color = inspectorColorFlag.color
        colorPanel.orderFront(sender)
    }
    
    @IBAction func previewSliderChanged(_ sender: NSSlider) {
        previewAction(sender, toMagnification: CGFloat(pow(2, sender.doubleValue)))
        previewSliderLabel.isHidden = NSEvent.pressedMouseButtons & 1 != 1
    }
    
}

extension SidebarController: ScreenshotLoader {
    
    func resetController() {
        imageLabel.stringValue = "Open or drop an image here."
        inspectorColorFlag.image = NSImage()
        inspectorColorLabel.stringValue = """
R:
G:
B:
A:
"""
        inspectorAreaLabel.stringValue = """
CSS:
@
"""
        previewSlider.isEnabled = false
    }
    
    func load(_ screenshot: Screenshot) throws {
        guard let image = screenshot.image else {
            throw ScreenshotError.invalidImage
        }
        guard let source = screenshot.image?.imageSourceRep, let url = screenshot.fileURL else {
            throw ScreenshotError.invalidImageSource
        }
        self.screenshot = screenshot
        try renderImageSource(source, itemURL: url)
        
        let previewSize = image.size.toCGSize()
        let previewRect = CGRect(origin: .zero, size: previewSize).aspectFit(in: previewImageView.bounds)
        let previewImage = image.downsample(to: previewRect.size, scale: NSScreen.main?.backingScaleFactor ?? 1.0)
        previewImageView.image = previewImage
        previewOverlayView.imageSize = previewSize
        previewOverlayView.highlightArea = previewRect
        previewSlider.isEnabled = true
    }
    
    fileprivate func renderImageSource(_ source: CGImageSource, itemURL: URL) throws {
        guard let fileProps = CGImageSourceCopyProperties(source, nil) as? [AnyHashable: Any] else {
            return
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            return
        }
        let createdAtStr = (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "Unknown"
        var createdAt: Date?
        if let date = SidebarController.exifDateFormatter.date(from: createdAtStr) {
            createdAt = date
        } else {
            let attrs = try FileManager.default.attributesOfItem(atPath: itemURL.path)
            createdAt = attrs[.creationDate] as? Date
        }
        var createdAtDesc: String?
        if let createdAt = createdAt {
            createdAtDesc = SidebarController.defaultDateFormatter.string(from: createdAt)
        }
        let fileSize = SidebarController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0
        imageLabel.stringValue = """
\(itemURL.lastPathComponent) (\(fileSize))

Created: \(createdAtDesc ?? "Unknown")
Dimensions: \(pixelXDimension)×\(pixelYDimension)
Orientation: \(props[kCGImagePropertyOrientation] ?? "Unknown")
Color Space: \(props[kCGImagePropertyColorModel] ?? "Unknown")
Color Profile: \(props[kCGImagePropertyProfileName] ?? "Unknown")
"""
    }
    
}

extension SidebarController: PreviewResponder {
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        previewOverlayDelegate?.previewAction(sender, centeredAt: coordinate)
    }
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat) {
        previewOverlayDelegate?.previewAction(sender, toMagnification: magnification)
    }
    
}
