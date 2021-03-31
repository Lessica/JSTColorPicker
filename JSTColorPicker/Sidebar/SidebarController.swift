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
    static let togglePaneViewTagList = NSUserInterfaceItemIdentifier("toggle-taglist")
}

class SidebarController: NSViewController {
    
    private enum PaneDividerIndex: Int {
        
        case info = 0
        case inspector
        case preview
        case taglist
         
        static var all: IndexSet {
            IndexSet([
                PaneDividerIndex.info.rawValue,
                PaneDividerIndex.inspector.rawValue,
                PaneDividerIndex.preview.rawValue,
                PaneDividerIndex.taglist.rawValue,
            ])
        }
        
    }
    
    internal weak var screenshot                 : Screenshot?
    
    @IBOutlet weak var splitView                 : NSSplitView!
    
    @IBOutlet weak var imageLabel1               : NSTextField!
    @IBOutlet weak var imageLabel2               : NSTextField!
    @IBOutlet weak var imageActionView           : NSView!
    @IBOutlet weak var exitComparisonModeButton  : NSButton!
    
    @IBOutlet weak var paneViewInfo              : NSView!
    @IBOutlet weak var paneViewInspector         : NSView!
    @IBOutlet weak var paneViewPreview           : NSView!
    @IBOutlet weak var paneViewTagList           : NSView!
    @IBOutlet weak var paneViewPlaceholder       : NSView!
    @IBOutlet weak var placeholderConstraint     : NSLayoutConstraint!
    
    private var imageSource                      : PixelImage.Source? { screenshot?.image?.imageSource }
    private var altImageSource                   : PixelImage.Source?
    private var exitComparisonHandler            : ((Bool) -> Void)?
    
    @IBOutlet weak var inspectorColorLabel       : NSTextField!
    @IBOutlet weak var inspectorColorFlag        : ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel        : NSTextField!
    
    @IBOutlet weak var inspectorColorLabelAlt    : NSTextField!
    @IBOutlet weak var inspectorColorFlagAlt     : ColorIndicator!
    @IBOutlet weak var inspectorAreaLabelAlt     : NSTextField!
    
    internal var previewStage                    : ItemPreviewStage = .none
    public weak var previewOverlayDelegate       : ItemPreviewResponder!
    @IBOutlet weak var previewImageView          : PreviewImageView!
    @IBOutlet weak var previewOverlayView        : PreviewOverlayView!
    @IBOutlet weak var previewSlider             : NSSlider!
    @IBOutlet weak var previewSliderBgView       : NSView!
    @IBOutlet weak var previewSliderLabel        : NSTextField!
    
    private var documentObservations             : [NSKeyValueObservation]?
    private var lastStoredRect                   : CGRect?
    private var lastStoredMagnification          : CGFloat?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = colorPanel
        previewSliderLabel.textColor = .white
        previewOverlayView.overlayDelegate = self
        
        lastStoredRect = nil
        lastStoredMagnification = nil
        
        updateInformationPanel()
        resetInspector()
        resetPreview()
        
        previewSlider.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        applyPreferences(nil)
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    
    // MARK: - Panes
    
    @IBOutlet var paneMenu: NSMenu!
    
    @objc private func applyPreferences(_ notification: Notification?) {
        updatePanesIfNeeded()
    }
    
    @IBAction func resetPanes(_ sender: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.resetPanes(sender)
    }
    
    @IBAction func togglePane(_ sender: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.togglePane(sender)
    }
    
    private func updatePanesIfNeeded() {
        var paneChanged = false
        var hiddenValue: Bool!
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInformation]
        if paneViewInfo.isHidden != hiddenValue {
            paneViewInfo.isHidden = hiddenValue
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInspector]
        if paneViewInspector.isHidden != hiddenValue {
            paneViewInspector.isHidden = hiddenValue
            if !hiddenValue {
                resetInspector()
            }
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewPreview]
        if paneViewPreview.isHidden != hiddenValue {
            paneViewPreview.isHidden = hiddenValue
            if !hiddenValue {
                resetPreview()
            }
            paneChanged = true
        }

        hiddenValue = !UserDefaults.standard[.togglePaneViewTagList]
        if paneViewTagList.isHidden != hiddenValue {
            paneViewTagList.isHidden = hiddenValue
            paneChanged = true
        }

        let resetValue: Bool = UserDefaults.standard[.resetPaneView]
        if resetValue {
            UserDefaults.standard[.resetPaneView] = false
            resetDividers()
        }
        
        placeholderConstraint.priority = hiddenValue ? .defaultLow : .defaultHigh

        if paneChanged {
            splitView.adjustSubviews()
            splitView.displayIfNeeded()
        }
    }
    
    @IBOutlet weak var dividerConstraintInfo       : NSLayoutConstraint!
    @IBOutlet weak var dividerConstraintInspector  : NSLayoutConstraint!
    @IBOutlet weak var dividerConstraintPreview    : NSLayoutConstraint!
    
    private func resetDividers(in set: IndexSet? = nil) {
        var dividerIndexes = set ?? PaneDividerIndex.all
        if paneViewInfo.isHidden {
            dividerIndexes.remove(PaneDividerIndex.info.rawValue)
        }
        if paneViewInspector.isHidden {
            dividerIndexes.remove(PaneDividerIndex.inspector.rawValue)
        }
        if paneViewPreview.isHidden {
            dividerIndexes.remove(PaneDividerIndex.preview.rawValue)
        }
        if paneViewTagList.isHidden {
            dividerIndexes.remove(PaneDividerIndex.taglist.rawValue)
        }
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(splitView.maxPossiblePositionOfDivider(at: $0), ofDividerAt: $0) })
        }
    }
    
}

extension SidebarController: ScreenshotLoader {
    
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
    
    func load(_ screenshot: Screenshot) throws {
        
        guard let image = screenshot.image else {
            throw Screenshot.Error.invalidImage
        }
        
        self.screenshot = screenshot
        self.altImageSource = nil
        
        lastStoredRect = nil
        lastStoredMagnification = nil
        
        updateInformationPanel()
        resetInspector()
        resetPreview()
        
        let previewSize = image.size.toCGSize()
        let previewRect = CGRect(origin: .zero, size: previewSize).aspectFit(in: previewImageView.bounds)
        let previewImage = image.downsample(to: previewRect.size, scale: NSScreen.main?.backingScaleFactor ?? 1.0)
        
        previewImageView.setImage(previewImage)
        previewOverlayView.imageSize = previewSize
        previewOverlayView.highlightArea = previewRect
        
        previewSlider.isEnabled = true
        resetDividers()
        
        documentObservations = [
            screenshot.observe(\.fileURL, options: [.new]) { [unowned self] (_, change) in
                self.updateInformationPanel()
            }
        ]
        
    }
    
    private func updateInformationPanel() {
        
        imageLabel1.isHidden = false
        if let imageSource1 = imageSource, let attributedText = attributedStringValue(for: imageSource1) {
            imageLabel1.attributedStringValue = attributedText
        }
        else {
            imageLabel1.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel")
        }
        
        if let imageSource2 = altImageSource, let attributedText = attributedStringValue(for: imageSource2) {
            imageLabel2.attributedStringValue = attributedText
            imageLabel2.isHidden = false
            imageActionView.isHidden = false
        }
        else {
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
            createdAtDesc = SidebarController.defaultDateFormatter.string(from: createdAt)
        }
        var modifiedAtDesc: String?
        if let modifiedAt = attrs[.modificationDate] as? Date {
            modifiedAtDesc = SidebarController.defaultDateFormatter.string(from: modifiedAt)
        }
        
        let snapshotAtStr = (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "Unknown"
        var snapshotAtDesc: String?
        if let snapshotAt = SidebarController.exifDateFormatter.date(from: snapshotAtStr) {
            snapshotAtDesc = SidebarController.defaultDateFormatter.string(from: snapshotAt)
        }
        
        let fileSize = SidebarController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
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

extension SidebarController: ItemInspector {
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.touchBar = nil
        return panel
    }
    
    @IBAction func colorIndicatorTapped(_ sender: ColorIndicator) {
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = sender.color
        
        colorPanel.makeKeyAndOrderFront(self)
    }
    
    func inspectItem(_ item: ContentItem, shouldSubmit submit: Bool) {
        
        guard !paneViewInspector.isHidden else {
            
            if let color = item as? PixelColor,
                submit && colorPanel.isVisible
            {
                let nsColor = color.toNSColor()
                
                colorPanel.setTarget(nil)
                colorPanel.setAction(nil)
                colorPanel.color = nsColor
            }
            
            return
        }
        
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
                inspectorColorLabelAlt.stringValue = """
R:\(String(color.red).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.red).leftPadding(to: 6, with: " "))
G:\(String(color.green).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.green).leftPadding(to: 6, with: " "))
B:\(String(color.blue).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.blue).leftPadding(to: 6, with: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(to: 5, with: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(to: 5, with: " "))
"""
                let nsColor = color.toNSColor()
                inspectorColorFlagAlt.color = nsColor
                inspectorColorFlagAlt.setImage(NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size))
                inspectorAreaLabelAlt.stringValue = """
CSS:\(color.cssString.leftPadding(to: 9, with: " "))
\(color.coordinate.description.leftPadding(to: 13, with: " "))
"""
                if colorPanel.isVisible {
                    colorPanel.setTarget(nil)
                    colorPanel.setAction(nil)
                    colorPanel.color = nsColor
                }
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
                inspectorAreaLabelAlt.stringValue = """
W:\(String(area.rect.width).leftPadding(to: 11, with: " "))
H:\(String(area.rect.height).leftPadding(to: 11, with: " "))
"""
            }
        }
        
    }
    
    private func resetInspector() {
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
        inspectorColorFlagAlt.setImage(NSImage(color: .clear, size: inspectorColorFlagAlt.bounds.size))
        inspectorColorLabelAlt.stringValue = """
R:\("-".leftPadding(to: 11, with: " "))
G:\("-".leftPadding(to: 11, with: " "))
B:\("-".leftPadding(to: 11, with: " "))
A:\("-".leftPadding(to: 11, with: " "))
"""
        inspectorAreaLabelAlt.stringValue = """
CSS:\("-".leftPadding(to: 9, with: " "))
\("-".leftPadding(to: 13, with: " "))
"""
    }
    
}

extension SidebarController: ItemPreviewDelegate {
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sender = sender else { return }
        updatePreview(to: rect, magnification: sender.wrapperRestrictedMagnification)
    }
    
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?) {
        guard let rect = rect,
            let magnification = magnification else { return }
        updatePreview(to: rect, magnification: magnification)
    }
    
    func updatePreview(to rect: CGRect, magnification: CGFloat) {
        guard !paneViewPreview.isHidden else {
            lastStoredRect = rect
            lastStoredMagnification = magnification
            return
        }
        
        if let imageSize = screenshot?.image?.size, !rect.isEmpty {
            
            let imageBounds = CGRect(origin: .zero, size: imageSize.toCGSize())
            let imageRestrictedRect = rect.intersection(imageBounds)
            
            let previewRect = imageBounds.aspectFit(in: previewImageView.bounds)
            let previewScale = min(previewRect.width / CGFloat(imageSize.width), previewRect.height / CGFloat(imageSize.height))
            
            let highlightRect = CGRect(x: previewRect.minX + imageRestrictedRect.minX * previewScale, y: previewRect.minY + imageRestrictedRect.minY * previewScale, width: imageRestrictedRect.width * previewScale, height: imageRestrictedRect.height * previewScale)
            
            previewOverlayView.highlightArea = highlightRect
            
        } else {
            previewOverlayView.highlightArea = .null
        }
        
        previewSliderLabel.stringValue = "\(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        previewSlider.doubleValue = Double(log2(magnification))
    }
    
    private func resetPreview() {
        guard let lastStoredRect = lastStoredRect,
            let lastStoredMagnification = lastStoredMagnification else { return }
        updatePreview(to: lastStoredRect, magnification: lastStoredMagnification)
    }
    
}

extension SidebarController: ItemPreviewSender, ItemPreviewResponder {
    
    @IBAction func previewSliderValueChanged(_ sender: NSSlider) {
        let isPressed = !(NSEvent.pressedMouseButtons & 1 != 1)
        if isPressed {
            if previewStage == .none || previewStage == .end {
                previewStage = .begin
            } else if previewStage == .begin {
                previewStage = .inProgress
            }
        } else {
            if previewStage == .begin || previewStage == .inProgress {
                previewStage = .end
            } else if previewStage == .end {
                previewStage = .none
            }
        }
        previewAction(self, toMagnification: CGFloat(pow(2, sender.doubleValue)))
        previewSliderLabel.isHidden = !isPressed
        previewSliderBgView.isHidden = !isPressed
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        previewOverlayDelegate.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        previewOverlayDelegate.previewAction(sender, atRelativePosition: position, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        previewOverlayDelegate.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        previewOverlayDelegate.previewAction(sender, toMagnification: magnification)
    }
    
}

extension SidebarController: PixelMatchResponder {
    
    @IBAction func exitComparisonModeButtonTapped(_ sender: NSButton) {
        if let exitComparisonHandler = exitComparisonHandler {
            exitComparisonHandler(true)
        }
    }
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        altImageSource = image.imageSource
        exitComparisonHandler = completionHandler
        updateInformationPanel()
        resetDividers(in: IndexSet(integer: PaneDividerIndex.info.rawValue))
    }
    
    func endPixelMatchComparison() {
        altImageSource = nil
        exitComparisonHandler = nil
        updateInformationPanel()
        resetDividers(in: IndexSet(integer: PaneDividerIndex.info.rawValue))
    }
    
    private var isInComparisonMode: Bool {
        return imageSource != nil && altImageSource != nil
    }
    
}

extension SidebarController: NSMenuItemValidation, NSMenuDelegate {
    
    private var hasAttachedSheet: Bool { view.window?.attachedSheet != nil }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !hasAttachedSheet else { return false }
        if menuItem.action == #selector(togglePane(_:)) || menuItem.action == #selector(resetPanes(_:)) {
            return true
        }
        guard screenshot != nil else { return false }
        return true
    }
    
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
                else if menuItem.identifier == .togglePaneViewTagList {
                    menuItem.state = UserDefaults.standard[.togglePaneViewTagList] ? .on : .off
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
    
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }
    
}

extension SidebarController {
    
    public var tagListController: TagListController! {
        return children.first as? TagListController
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        guard segue.identifier == "TagListContainer" && segue.destinationController is TagListController else { return }
    }
    
}

