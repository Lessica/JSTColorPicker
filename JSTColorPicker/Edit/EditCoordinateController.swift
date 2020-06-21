//
//  EditCoordinateController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditCoordinateController: EditViewController {
    
    @IBOutlet weak var box          : NSBox!
    @IBOutlet weak var previewBox   : NSBox!
    
    @IBOutlet weak var toggleBtn    : NSButton!
    @IBOutlet weak var cancelBtn    : NSButton!
    @IBOutlet weak var okBtn        : NSButton!
    
    @IBOutlet weak var touchBarToggleBtn    : NSButton!
    @IBOutlet weak var touchBarCancelBtn    : NSButton!
    @IBOutlet weak var touchBarOkBtn        : NSButton!
    
    @IBOutlet weak var textFieldOriginX: NSTextField!
    @IBOutlet weak var textFieldOriginY: NSTextField!
    @IBOutlet weak var textFieldColor  : NSTextField!
    @IBOutlet weak var textFieldError  : NSTextField!
    
    @IBOutlet weak var previewImageView  : PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let previewOn: Bool = UserDefaults.standard[.togglePreviewColor]
        previewBox.isHidden = !previewOn
        
        let toggleOn: NSControl.StateValue = previewBox.isHidden ? .on : .off
        toggleBtn.state = toggleOn
        touchBarToggleBtn.state = toggleOn
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        undoManager?.disableUndoRegistration()
        setupPreviewIfNeeded()
        updateDisplay(nil, with: contentItem)
        if isAdd {
            box.title = NSLocalizedString("New Color & Coordinate", comment: "EditCoordinateController")
        } else {
            box.title = NSLocalizedString("Edit Color & Coordinate", comment: "EditCoordinateController")
            validateInputs(view)
        }
        undoManager?.enableUndoRegistration()
        
        undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: nil)
        { [unowned self] (notification) in
            guard (notification.object as? UndoManager) == self.undoManager else { return }
            self.validateInputs(nil)
        }
        redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: nil)
        { [unowned self] (notification) in
            guard (notification.object as? UndoManager) == self.undoManager else { return }
            self.validateInputs(nil)
        }
    }
    
    private var lastDisplayedColor: PixelColor?
    
    private var currentCoordinate: PixelCoordinate {
        if textFieldOriginX.stringValue.isEmpty || textFieldOriginY.stringValue.isEmpty {
            return .null
        }
        return PixelCoordinate(
            x: textFieldOriginX.integerValue,
            y: textFieldOriginY.integerValue
        )
    }
    
    private func updateDisplay(_ sender: Any?, with item: ContentItem?) {
        guard let pixelColor = item as? PixelColor else { return }
        
        let coord = pixelColor.coordinate
        textFieldOriginX.stringValue   = String(coord.x)
        textFieldOriginY.stringValue   = String(coord.y)
        textFieldColor  .stringValue   = "\u{25CF} \(pixelColor.cssString)"
        
        let nsColor = pixelColor.toNSColor()
        textFieldColor.textColor       = nsColor
        textFieldColor.backgroundColor = (nsColor.isLightColor ?? false) ? .black : .white
        
        if let lastDisplayedColor = lastDisplayedColor, lastDisplayedColor.coordinate != pixelColor.coordinate, sender != nil
        {
            undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
                if let field = sender as? NSTextField, targetSelf.firstResponder != field
                {
                    targetSelf.makeFirstResponder(field)
                } else {
                    targetSelf.makeFirstResponder(nil)
                }
                targetSelf.updateDisplay(sender, with: lastDisplayedColor)
            })
        }
        
        updatePreview(to: coord.toCGPoint())
        if sender != nil {
            lastDisplayedColor = pixelColor
        }
    }
    
    private func testContentItem(with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentItemSource else { return nil }
        let replItem = try dataSource.contentItem(of: PixelCoordinate(x: textFieldOriginX.integerValue, y: textFieldOriginY.integerValue))
        if let origItem = item {
            replItem.copyFrom(origItem)
        }
        return replItem
    }
    
    @IBAction private func validateInputs(_ sender: Any?) {
        internalValidateInputs(sender)
    }
    
    @discardableResult
    private func internalValidateInputs(_ sender: Any?) -> ContentItem? {
        do {
            let item = try testContentItem()
            updateDisplay(sender, with: item)
            
            let okEnabled = (item != contentItem)
            okBtn.isEnabled = okEnabled
            touchBarOkBtn.isEnabled = okEnabled
            
            textFieldError.isHidden = true
            return item
        } catch {
            textFieldError.stringValue = "\n\(error.localizedDescription)"
            
            okBtn.isEnabled = false
            touchBarOkBtn.isEnabled = false
            
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
            if let replItem = try testContentItem(with: origItem) as? PixelColor
            {
                if isAdd {
                    if let _ = try delegate.addContentItem(of: replItem.coordinate) {
                        parent.endSheet(window, returnCode: .OK)
                    }
                } else {
                    guard let origItem = origItem else { return }
                    if let _ = try delegate.updateContentItem(origItem, to: replItem.coordinate) {
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
        
        let toggleOn: NSControl.StateValue = previewBox.isHidden ? .on : .off
        toggleBtn.state = toggleOn
        touchBarToggleBtn.state = toggleOn
        
        UserDefaults.standard[.togglePreviewColor] = !previewBox.isHidden
        
        setupPreviewIfNeeded()
        if !previewBox.isHidden {
            updatePreview(to: currentCoordinate.toCGPoint())
        }
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
    
    private func updatePreview(to point: CGPoint) {
        guard didSetupPreview && !point.isNull else { return }
        guard let imageSize = image?.size else { return }
        
        let rect = CGRect(at: point, radius: 1.0)
        let previewRect = CGRect(origin: .zero, size: imageSize.toCGSize()).aspectFit(in: previewImageView.bounds)
        let previewScale = min(previewRect.width / CGFloat(imageSize.width), previewRect.height / CGFloat(imageSize.height))
        let highlightRect = CGRect(x: previewRect.minX + rect.minX * previewScale, y: previewRect.minY + rect.minY * previewScale, width: rect.width * previewScale, height: rect.height * previewScale)
        previewOverlayView.highlightArea = highlightRect
    }
    
    private func resetPreview() {
        guard didSetupPreview else { return }
        previewOverlayView.highlightArea = CGRect.null
    }
    
    deinit {
        debugPrint("- [EditCoordinateController deinit]")
    }
    
}

extension EditCoordinateController: PreviewResponder {
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        guard let image = image else { return }
        
        makeFirstResponder(nil)
        updateDisplay(nil, with: image.color(at: coordinate))
        internalValidateInputs(sender)
    }
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) { }
    
}

