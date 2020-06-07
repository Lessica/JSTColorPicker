//
//  EditAreaController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditAreaController: EditViewController {
    
    @IBOutlet weak var box          : NSBox!
    @IBOutlet weak var previewBox   : NSBox!

    @IBOutlet weak var toggleBtn    : NSButton!
    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    
    @IBOutlet weak var textFieldOriginX  : NSTextField!
    @IBOutlet weak var textFieldOriginY  : NSTextField!
    @IBOutlet weak var textFieldWidth    : NSTextField!
    @IBOutlet weak var textFieldHeight   : NSTextField!
    @IBOutlet weak var textFieldOppositeX: NSTextField!
    @IBOutlet weak var textFieldOppositeY: NSTextField!
    
    @IBOutlet weak var textFieldError    : NSTextField!
    
    @IBOutlet weak var previewImageView  : PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previewOn: Bool = UserDefaults.standard[.togglePreviewArea]
        previewBox.isHidden = !previewOn
        toggleBtn.state = previewBox.isHidden ? .on : .off
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        undoManager?.disableUndoRegistration()
        setupPreviewIfNeeded()
        updateDisplay(with: (contentItem as? PixelArea)?.rect)
        if isAdd {
            box.title = NSLocalizedString("New Area", comment: "EditAreaController")
        } else {
            box.title = NSLocalizedString("Edit Area", comment: "EditAreaController")
            validateInputs(nil)
        }
        undoManager?.enableUndoRegistration()
    }
    
    private var lastRectangle: PixelRect?
    
    private var currentRectangle: PixelRect {
        PixelRect(
            x: textFieldOriginX.integerValue,
            y: textFieldOriginY.integerValue,
            width: textFieldWidth.integerValue,
            height: textFieldHeight.integerValue
        )
    }
    
    private func updateDisplay(with rect: PixelRect?) {
        guard let rect = rect else { return }
        
        textFieldOriginX  .stringValue = String(rect.minX)
        textFieldOriginY  .stringValue = String(rect.minY)
        textFieldWidth    .stringValue = String(rect.width)
        textFieldHeight   .stringValue = String(rect.height)
        textFieldOppositeX.stringValue = String(rect.maxX)
        textFieldOppositeY.stringValue = String(rect.maxY)
        
        updatePreview(to: rect.toCGRect())
        lastRectangle = rect
    }
    
    private func testContentItem(fromOpposite: Bool, with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentDataSource else { return nil }
        let replRect = (fromOpposite ?
            PixelRect(
                coordinate1: PixelCoordinate(
                    x: textFieldOriginX.integerValue,
                    y: textFieldOriginY.integerValue
                ),
                coordinate2: PixelCoordinate(
                    x: textFieldOppositeX.integerValue,
                    y: textFieldOppositeY.integerValue
                )
            ) :
            PixelRect(
                origin: PixelCoordinate(
                    x: textFieldOriginX.integerValue,
                    y: textFieldOriginY.integerValue
                ),
                size: PixelSize(
                    width: textFieldWidth.integerValue,
                    height: textFieldHeight.integerValue
                )
            )
        )
        let replItem = try dataSource.contentItem(of: replRect)
        if let origItem = item {
            replItem.copyFrom(origItem)
        }
        return replItem
    }
    
    @IBAction private func validateInputs(_ sender: NSTextField?) {
        internalValidateInputs(sender)
    }
    
    @discardableResult
    private func internalValidateInputs(_ sender: NSTextField?) -> ContentItem? {
        do {
            let item = try testContentItem(fromOpposite: sender == textFieldOppositeX || sender == textFieldOppositeY)
            updateDisplay(with: (item as? PixelArea)?.rect)
            okBtn.isEnabled = (item != contentItem)
            textFieldError.isHidden = true
            return item
        } catch {
            resetPreview()
            textFieldError.stringValue = "\n\(error.localizedDescription)"
            okBtn.isEnabled = false
            textFieldError.isHidden = false
        }
        return nil
    }
    
    @IBAction private func cancelAction(_ sender: NSButton) {
        guard let window = view.window, let parent = window.sheetParent else { return }
        parent.endSheet(window, returnCode: .cancel)
    }
    
    @IBAction private func okAction(_ sender: NSButton) {
        guard let delegate = contentDelegate else { return }
        guard let window = view.window, let parent = window.sheetParent else { return }
        do {
            let origItem: ContentItem? = contentItem
            if let replArea = try testContentItem(fromOpposite: false, with: origItem) as? PixelArea
            {
                if isAdd {
                    if let _ = try delegate.addContentItem(of: replArea.rect) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                } else {
                    guard let origItem = origItem else { return }
                    if let _ = try delegate.updateContentItem(origItem, to: replArea.rect) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                }
            }
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func toggleAction(_ sender: NSButton) {
        previewBox.isHidden = !previewBox.isHidden
        sender.state = previewBox.isHidden ? .on : .off
        UserDefaults.standard[.togglePreviewArea] = !previewBox.isHidden
        
        setupPreviewIfNeeded()
    }
    
    private var didSetupPreview: Bool = false
    private func setupPreviewIfNeeded() {
        guard let image = image else { return }
        guard !previewBox.isHidden && !didSetupPreview else { return }
        didSetupPreview = true
        
        let previewSize = image.size.toCGSize()
        let previewRect = CGRect(origin: .zero, size: previewSize).aspectFit(in: previewImageView.bounds)
        let previewImage = image.downsample(to: previewRect.size, scale: NSScreen.main?.backingScaleFactor ?? 1.0)
        previewImageView.setImage(previewImage)
        previewOverlayView.imageSize = previewSize
        previewOverlayView.highlightArea = previewRect
        
        previewOverlayView.overlayDelegate = self
    }
    
    private func updatePreview(to rect: CGRect) {
        guard didSetupPreview && !rect.isEmpty else { return }
        guard let imageSize = image?.size else { return }
        
        let previewRect = CGRect(origin: .zero, size: imageSize.toCGSize()).aspectFit(in: previewImageView.bounds)
        let previewScale = min(previewRect.width / CGFloat(imageSize.width), previewRect.height / CGFloat(imageSize.height))
        let highlightRect = CGRect(x: previewRect.minX + rect.minX * previewScale, y: previewRect.minY + rect.minY * previewScale, width: rect.width * previewScale, height: rect.height * previewScale)
        previewOverlayView.highlightArea = highlightRect
    }
    
    private func resetPreview() {
        guard didSetupPreview else { return }
        previewOverlayView.highlightArea = CGRect.null
    }
    
}

extension EditAreaController: PreviewResponder {
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        guard let imageBounds = image?.bounds else { return }
        guard let origRect = (internalValidateInputs(nil) as? PixelArea)?.rect else { return }
        
        let point = coordinate.toCGPoint()
        let replRect = PixelRect(
            CGRect(
                x: point.x - CGFloat(origRect.width) / 2.0,
                y: point.y - CGFloat(origRect.height) / 2.0,
                width: CGFloat(origRect.width),
                height: CGFloat(origRect.height)
            )
        ).intersection(imageBounds)
        
        updateDisplay(with: replRect)
        validateInputs(nil)
    }
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) { }
    
}
