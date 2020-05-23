//
//  SidebarController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    static let togglePaneViewInformation = NSUserInterfaceItemIdentifier("toggle-info")
    static let togglePaneViewInspector = NSUserInterfaceItemIdentifier("toggle-inspector")
    static let togglePaneViewPreview = NSUserInterfaceItemIdentifier("toggle-preview")
}

enum PaneDividerIndex: Int {
    case information = 0
    case inspector
    case preview
}

class SidebarController: NSViewController {
    
    internal weak var screenshot: Screenshot?
    
    @IBOutlet weak var splitView: NSSplitView!
    
    @IBOutlet weak var imageLabel1: NSTextField!
    @IBOutlet weak var imageLabel2: NSTextField!
    @IBOutlet weak var imageActionView: NSView!
    @IBOutlet weak var exitComparisonModeButton: NSButton!
    
    @IBOutlet weak var paneViewInformation: NSView!
    @IBOutlet weak var paneViewInspector: NSView!
    @IBOutlet weak var paneViewPreview: NSView!
    @IBOutlet weak var paneViewPlaceholder: NSView!
    
    fileprivate var imageSource1: PixelImageSource? {
        return screenshot?.image?.imageSource
    }
    fileprivate var imageSource2: PixelImageSource?
    fileprivate var isInComparisonMode: Bool {
        return imageSource1 != nil && imageSource2 != nil
    }
    fileprivate var exitComparisonHandler: ((Bool) -> Void)?
    fileprivate func updateInformationPanel() {
        
        imageLabel1.isHidden = false
        if let imageSource1 = imageSource1, let text = stringValue(for: imageSource1) {
            imageLabel1.stringValue = text
        }
        else {
            imageLabel1.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel")
        }
        imageLabel1.displayIfNeeded()
        
        if let imageSource2 = imageSource2, let text = stringValue(for: imageSource2) {
            imageLabel2.stringValue = text
            imageLabel2.isHidden = false
            imageActionView.isHidden = false
        }
        else {
            imageLabel2.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel")
            imageLabel2.isHidden = true
            imageActionView.isHidden = true
        }
        imageLabel2.displayIfNeeded()
        
    }
    
    @IBOutlet weak var inspectorColorLabel: NSTextField!
    @IBOutlet weak var inspectorColorFlag: ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel: NSTextField!
    
    @IBOutlet weak var inspectorColorLabel2: NSTextField!
    @IBOutlet weak var inspectorColorFlag2: ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel2: NSTextField!
    
    @IBOutlet weak var previewImageView: PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    @IBOutlet weak var previewSlider: NSSlider!
    @IBOutlet weak var previewSliderLabel: NSTextField!
    weak var previewOverlayDelegate: PreviewResponder?
    
    @IBOutlet weak var exportButton: NSButton!
    @IBOutlet weak var optionButton: NSButton!
    
    fileprivate var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = false
        return panel
    }
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = colorPanel
        previewSliderLabel.textColor = .white
        previewOverlayView.overlayDelegate = self
        initializeController()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        loadPreferences(nil)
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
                inspectorColorFlag.setImage(NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size))
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
                inspectorColorFlag2.setImage(NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size))
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
        guard !rect.isEmpty else { return }
        
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
    
    @IBAction func exitComparisonModeButtonTapped(_ sender: NSButton) {
        if let exitComparisonHandler = exitComparisonHandler {
            exitComparisonHandler(true)
        }
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
    
    
    // MARK: -
    
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
        
        var itemIdx: Int = 0
        let items = exportManager.templates
            .compactMap({ [weak self] (template) -> NSMenuItem in
                
                itemIdx += 1
                var keyEqu = ""
                if itemIdx <= 10 {
                    keyEqu = String(format: "%d", itemIdx % 10)
                }
                
                let item = NSMenuItem(title: "\(template.name) (\(template.version))", action: #selector(templateItemTapped(_:)), keyEquivalent: keyEqu)
                item.target = self
                item.identifier = NSUserInterfaceItemIdentifier(rawValue: "\(templateIdentifierPrefix)\(template.uuid.uuidString)")
                item.keyEquivalentModifierMask = [.option, .command]
                
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
            .sorted(by: { $0.title.compare($1.title) == .orderedAscending })
        
        optionMenu.items = items + reservedOptionMenuItems
        optionMenu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        
    }
    
    @IBAction func reloadAllTemplatesMenuTapped(_ sender: NSMenuItem) {
        do {
            try screenshot?.export.reloadTemplates()
        }
        catch let error {
            presentError(error)
        }
    }
    
    @IBAction func showTemplatesMenuTapped(_ sender: NSMenuItem) {
        copyExampleTemplatesIfNeeded()
        NSWorkspace.shared.open(ExportManager.templateRootURL)
    }
    
    @IBAction func showLogsMenuTapped(_ sender: NSMenuItem) {
        let paths = [
            "/Applications/Utilities/Console.app",
            "/System/Applications/Utilities/Console.app"
        ]
        if let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path, isDirectory: true))
        }
    }
    
    @objc fileprivate func templateItemTapped(_ sender: NSMenuItem) {
        selectTemplateItem(sender)
    }
    
    fileprivate func selectTemplateItem(_ sender: NSMenuItem) {
        guard let identifier = sender.identifier?.rawValue else { return }
        guard identifier.lengthOfBytes(using: .utf8) > 0 else { return }
        let beginIdx = identifier.index(identifier.startIndex, offsetBy: templateIdentifierPrefix.lengthOfBytes(using: .utf8))
        let udidString = String(identifier[beginIdx...])
        screenshot?.export.selectedTemplateUUID = UUID(uuidString: udidString)
    }
    
    fileprivate func copyExampleTemplatesIfNeeded() {
        guard let exportManager = screenshot?.export else { return }
        if exportManager.templates.count == 0 {
            if let exampleTemplateURL = ExportManager.exampleTemplateURL {
                let exampleTemplateName = exampleTemplateURL.lastPathComponent
                let newExampleTemplateURL = ExportManager.templateRootURL.appendingPathComponent(exampleTemplateName)
                try? FileManager.default.copyItem(at: exampleTemplateURL, to: newExampleTemplateURL)
            }
            try? exportManager.reloadTemplates()
        }
    }
    
    
    // MARK: -
    
    @IBOutlet var paneMenu: NSMenu!
    
    @objc fileprivate func loadPreferences(_ notification: Notification?) {
        updatePanes()
    }
    
    @IBAction func resetPanes(_ sender: NSMenuItem) {
        resetDividers()
        
        UserDefaults.standard.removeObject(forKey: .togglePaneViewInformation)
        UserDefaults.standard.removeObject(forKey: .togglePaneViewInspector)
        UserDefaults.standard.removeObject(forKey: .togglePaneViewPreview)
        
        splitView.display()
    }
    
    @IBAction func togglePane(_ sender: NSMenuItem) {
        var defaultKey: UserDefaults.Key?
        if sender.identifier == .togglePaneViewInformation {
            defaultKey = .togglePaneViewInformation
        }
        else if sender.identifier == .togglePaneViewInspector {
            defaultKey = .togglePaneViewInspector
        }
        else if sender.identifier == .togglePaneViewPreview {
            defaultKey = .togglePaneViewPreview
        }
        if let key = defaultKey {
            let val: Bool = UserDefaults.standard[key]
            UserDefaults.standard[key] = !val
            sender.state = !val ? .on : .off
            
            splitView.display()
        }
    }
    
    fileprivate func updatePanes() {
        var paneChanged = false
        var hiddenValue: Bool!
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInformation]
        if paneViewInformation.isHidden != hiddenValue {
            paneViewInformation.isHidden = hiddenValue
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInspector]
        if paneViewInspector.isHidden != hiddenValue {
            paneViewInspector.isHidden = hiddenValue
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewPreview]
        if paneViewPreview.isHidden != hiddenValue {
            paneViewPreview.isHidden = hiddenValue
            paneChanged = true
        }
        
        if paneChanged {
            splitView.adjustSubviews()
            splitView.display()
        }
    }
    
    fileprivate func resetDividers() {
        var dividerPos: CGFloat = 0
        
        if !paneViewInformation.isHidden {
            dividerPos += paneViewInformation.subviews.first!.frame.height
            splitView.setPosition(dividerPos, ofDividerAt: PaneDividerIndex.information.rawValue)
            dividerPos += splitView.dividerThickness
        }
        
        if !paneViewInspector.isHidden {
            dividerPos += paneViewInspector.subviews.first!.frame.height
            splitView.setPosition(dividerPos, ofDividerAt: PaneDividerIndex.inspector.rawValue)
            dividerPos += splitView.dividerThickness
        }
        
        if !paneViewPreview.isHidden {
            dividerPos += paneViewPreview.subviews.first!.frame.height
            splitView.setPosition(dividerPos, ofDividerAt: PaneDividerIndex.preview.rawValue)
            dividerPos += splitView.dividerThickness
        }
    }
    
}

extension SidebarController: ScreenshotLoader {
    
    func initializeController() {
        updateInformationPanel()
        
        inspectorColorFlag.setImage(NSImage(color: .clear, size: inspectorColorFlag.bounds.size))
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
        inspectorColorFlag2.setImage(NSImage(color: .clear, size: inspectorColorFlag2.bounds.size))
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
        exportButton.isEnabled = false
        optionButton.isEnabled = false
        
        reservedOptionMenuItems.removeAll()
        reservedOptionMenuItems.append(contentsOf: optionMenu.items)
    }
    
    func load(_ screenshot: Screenshot) throws {
        guard let image = screenshot.image else { throw ScreenshotError.invalidImage }
        self.screenshot = screenshot
        self.imageSource2 = nil
        updateInformationPanel()
        
        let previewSize = image.size.toCGSize()
        let previewRect = CGRect(origin: .zero, size: previewSize).aspectFit(in: previewImageView.bounds)
        let previewImage = image.downsample(to: previewRect.size, scale: NSScreen.main?.backingScaleFactor ?? 1.0)
        previewImageView.setImage(previewImage)
        previewOverlayView.imageSize = previewSize
        previewOverlayView.highlightArea = previewRect
        
        previewSlider.isEnabled = true
        exportButton.isEnabled = true
        optionButton.isEnabled = true
        
        resetDividers()
        
        copyExampleTemplatesIfNeeded()
    }
    
    fileprivate func stringValue(for source: PixelImageSource) -> String? {
        guard let fileProps = CGImageSourceCopyProperties(source.cgSource, nil) as? [AnyHashable: Any] else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source.cgSource, 0, nil) as? [AnyHashable: Any] else { return nil }
        let createdAtStr = (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "Unknown"
        var createdAt: Date?
        if let date = SidebarController.exifDateFormatter.date(from: createdAtStr) {
            createdAt = date
        } else {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: source.url.path) else { return nil }
            createdAt = attrs[.creationDate] as? Date
        }
        var createdAtDesc: String?
        if let createdAt = createdAt {
            createdAtDesc = SidebarController.defaultDateFormatter.string(from: createdAt)
        }
        let fileSize = SidebarController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0
        return """
\(source.url.lastPathComponent) (\(fileSize))

Created: \(createdAtDesc ?? "Unknown")
Dimensions: \(pixelXDimension)×\(pixelYDimension)
Color Space: \(props[kCGImagePropertyColorModel] ?? "Unknown")
Color Profile: \(props[kCGImagePropertyProfileName] ?? "Unknown")
"""
    }
    
}

extension SidebarController: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard screenshot != nil else { return false }
        if item.action == #selector(togglePane(_:)) {
            return true
        }
        else if item.action == #selector(resetPanes(_:)) {
            return true
        }
        return false
    }
    
}

extension SidebarController: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        
        if menu == paneMenu {
            menu.items.forEach { (menuItem) in
                if menuItem.identifier == .togglePaneViewInformation {
                    menuItem.state = UserDefaults.standard[.togglePaneViewInformation] ? .on : .off
                }
                else if menuItem.identifier == .togglePaneViewInspector {
                    menuItem.state = UserDefaults.standard[.togglePaneViewInspector] ? .on : .off
                }
                else if menuItem.identifier == .togglePaneViewPreview {
                    menuItem.state = UserDefaults.standard[.togglePaneViewPreview] ? .on : .off
                }
            }
        }
        
    }
    
}

extension SidebarController: NSSplitViewDelegate {
    
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
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

extension SidebarController: PixelMatchResponder {
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        imageSource2 = image.imageSource
        exitComparisonHandler = completionHandler
        updateInformationPanel()
    }
    
    func endPixelMatchComparison() {
        imageSource2 = nil
        exitComparisonHandler = nil
        updateInformationPanel()
    }
    
}

