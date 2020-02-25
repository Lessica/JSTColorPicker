//
//  SidebarController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension String {
    func leftPadding(to length: Int, with character: Character) -> String {
        if length <= self.count {
            return String(self)
        }
        let newLength = self.count
        if newLength < length {
            return String(repeatElement(character, count: length - newLength)) + self
        } else {
            let idx = self.index(self.startIndex, offsetBy: newLength - length)
            return String(self[..<idx])
        }
    }
}

extension String {
    
    // Modified from the DragonCherry extension - https://github.com/DragonCherry/VersionCompare
    private func compare(toVersion targetVersion: String) -> ComparisonResult {
        let versionDelimiter = "."
        var result: ComparisonResult = .orderedSame
        var versionComponents = components(separatedBy: versionDelimiter)
        var targetComponents = targetVersion.components(separatedBy: versionDelimiter)
        
        while versionComponents.count < targetComponents.count {
            versionComponents.append("0")
        }
        while targetComponents.count < versionComponents.count {
            targetComponents.append("0")
        }
        
        for (version, target) in zip(versionComponents, targetComponents) {
            result = version.compare(target, options: .numeric)
            if result != .orderedSame {
                break
            }
        }
        
        return result
    }
    
    func isVersion(equalTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedSame }
    func isVersion(greaterThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedDescending }
    func isVersion(greaterThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedAscending }
    func isVersion(lessThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedAscending }
    func isVersion(lessThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedDescending }
    
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size, flipped: false) { (rect) -> Bool in
            color.drawSwatch(in: NSRect(origin: .zero, size: rect.size))
            return true
        }
        cacheMode = .never
    }
}

class SidebarController: NSViewController {
    
    internal weak var screenshot: Screenshot?
    
    @IBOutlet weak var imageLabel: NSTextField!
    
    @IBOutlet weak var inspectorColorLabel: NSTextField!
    @IBOutlet weak var inspectorColorFlag: ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel: NSTextField!
    
    @IBOutlet weak var inspectorColorLabel2: NSTextField!
    @IBOutlet weak var inspectorColorFlag2: ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel2: NSTextField!
    
    @IBOutlet weak var previewImageView: PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    @IBOutlet weak var previewSlider: PreviewSlider!
    @IBOutlet weak var previewSliderLabel: NSTextField!
    weak var previewOverlayDelegate: PreviewResponder?
    
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var optionButton: NSButton!
    
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
        previewSliderLabel.textColor = .white
        colorPanel.mode = .RGB
        colorPanel.showsAlpha = true
        // colorPanel.styleMask
        previewOverlayView.overlayDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeController()
    }
    
    func updateItemInspector(for item: ContentItem, submit: Bool) {
        if let color = item as? PixelColor {
            
            if !submit {
                inspectorColorLabel.stringValue = """
R:\(String(color.red).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.red).leftPadding(to: 6, with: " "))
G:\(String(color.green).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.green).leftPadding(to: 6, with: " "))
B:\(String(color.blue).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.blue).leftPadding(to: 6, with: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(to: 5, with: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(to: 5, with: " "))
"""
                let nsColor = color.toNSColor()
                inspectorColorFlag.color = nsColor
                inspectorColorFlag.image = NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size)
                inspectorAreaLabel.stringValue = """
CSS:\(color.cssString.leftPadding(to: 9, with: " "))
\(color.coordinate.description.leftPadding(to: 13, with: " "))
"""
            }
            else {
                inspectorColorLabel2.stringValue = """
R:\(String(color.red).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.red).leftPadding(to: 6, with: " "))
G:\(String(color.green).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.green).leftPadding(to: 6, with: " "))
B:\(String(color.blue).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.blue).leftPadding(to: 6, with: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(to: 5, with: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(to: 5, with: " "))
"""
                let nsColor = color.toNSColor()
                inspectorColorFlag2.color = nsColor
                inspectorColorFlag2.image = NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size)
                inspectorAreaLabel2.stringValue = """
CSS:\(color.cssString.leftPadding(to: 9, with: " "))
\(color.coordinate.description.leftPadding(to: 13, with: " "))
"""
                colorPanel.color = nsColor
            }
        }
        else if let area = item as? PixelArea {
            if !submit {
                inspectorAreaLabel.stringValue = """
W:\(String(area.rect.width).leftPadding(to: 11, with: " "))
H:\(String(area.rect.height).leftPadding(to: 11, with: " "))
"""
            }
            else {
                inspectorAreaLabel2.stringValue = """
W:\(String(area.rect.width).leftPadding(to: 11, with: " "))
H:\(String(area.rect.height).leftPadding(to: 11, with: " "))
"""
            }
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
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    @IBAction func colorIndicatorTapped(_ sender: ColorIndicator) {
        colorPanel.color = sender.color
        colorPanel.orderFront(sender)
    }
    
    @IBAction func previewSliderChanged(_ sender: NSSlider) {
        let isPressed = !(NSEvent.pressedMouseButtons & 1 != 1)
        previewAction(sender, toMagnification: CGFloat(pow(2, sender.doubleValue)), isChanging: isPressed)
        previewSliderLabel.isHidden = !isPressed
    }
    
    @IBOutlet var optionMenu: NSMenu!
    fileprivate var reservedOptionMenuItems: [NSMenuItem] = []
    fileprivate let templateIdentifierPrefix = "template-"
    
    @IBAction func exportButtonTapped(_ sender: NSButton) {
        do {
            guard let template = screenshot?.export.selectedTemplate else { throw ExportError.noTemplateSelected }
            let panel = NSSavePanel()
            panel.allowedFileTypes = template.allowedExtensions
            panel.beginSheetModal(for: view.window!) { (resp) in
                if resp == .OK {
                    if let url = panel.url {
                        self.exportAllItems(to: url)
                    }
                }
            }
        }
        catch let error {
            presentError(error)
        }
    }
    
    fileprivate func exportAllItems(to url: URL) {
        do {
            try screenshot?.export.exportAllItems(to: url)
        }
        catch let error {
            presentError(error)
        }
    }
    
    @IBAction func optionButtonTapped(_ sender: NSButton) {
        guard let exportManager = screenshot?.export else { return }
        let items = exportManager.templates.compactMap({ (template) -> NSMenuItem in
            let item = NSMenuItem(title: "\(template.name) (\(template.version))", action: #selector(templateItemTapped(_:)), keyEquivalent: "")
            item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(templateIdentifierPrefix)\(template.uuid.uuidString)")
            let enabled = Template.currentPlatformVersion.isVersion(greaterThanOrEqualTo: template.platformVersion)
            item.isEnabled = enabled
            item.state = template.uuid.uuidString == exportManager.selectedTemplate?.uuid.uuidString ? .on : .off
            if enabled {
                item.toolTip = """
\(template.name) (\(template.version))
by \(template.author ?? "Unknown")
------
\(template.description ?? "")
"""
            }
            else {
                item.toolTip = TemplateError.unsatisfiedPlatformVersion(version: template.platformVersion).failureReason
            }
            return item
        })
        optionMenu.items = items + reservedOptionMenuItems
        optionMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @IBAction func showInFinderMenuTapped(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(ExportManager.templateRoot)
    }
    
    @objc func templateItemTapped(_ sender: NSMenuItem) {
        selectTemplateItem(sender)
    }
    
    fileprivate func selectTemplateItem(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue else { return }
        guard identifier.lengthOfBytes(using: .utf8) > 0 else { return }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: templateIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udidString = String(identifier[beginIdx...])
        screenshot?.export.selectedTemplateUUID = UUID(uuidString: udidString)
    }
    
}

extension SidebarController: ScreenshotLoader {
    
    func initializeController() {
        imageLabel.stringValue = "Open or drop an image here."
        inspectorColorFlag.image = NSImage(color: .clear, size: inspectorColorFlag.bounds.size)
        inspectorColorLabel.stringValue = """
R:\("-".leftPadding(to: 11, with: " "))
G:\("-".leftPadding(to: 11, with: " "))
B:\("-".leftPadding(to: 11, with: " "))
A:\("-".leftPadding(to: 11, with: " "))
"""
        inspectorAreaLabel.stringValue = """
CSS:\("-".leftPadding(to: 9, with: " "))
\("-".leftPadding(to: 13, with: " "))
"""
        inspectorColorFlag2.image = NSImage(color: .clear, size: inspectorColorFlag2.bounds.size)
        inspectorColorLabel2.stringValue = """
R:\("-".leftPadding(to: 11, with: " "))
G:\("-".leftPadding(to: 11, with: " "))
B:\("-".leftPadding(to: 11, with: " "))
A:\("-".leftPadding(to: 11, with: " "))
"""
        inspectorAreaLabel2.stringValue = """
CSS:\("-".leftPadding(to: 9, with: " "))
\("-".leftPadding(to: 13, with: " "))
"""
        previewSlider.isEnabled = false
        reservedOptionMenuItems.removeAll()
        reservedOptionMenuItems.append(contentsOf: optionMenu.items)
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
Color Space: \(props[kCGImagePropertyColorModel] ?? "Unknown")
Color Profile: \(props[kCGImagePropertyProfileName] ?? "Unknown")
"""
    }
    
}

extension SidebarController: PreviewResponder {
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        previewOverlayDelegate?.previewAction(sender, centeredAt: coordinate)
    }
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) {
        previewOverlayDelegate?.previewAction(sender, toMagnification: magnification, isChanging: isChanging)
    }
    
}
