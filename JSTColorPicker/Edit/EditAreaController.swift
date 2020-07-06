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
    
    @IBOutlet weak var touchBarToggleBtn    : NSButton!
    @IBOutlet weak var touchBarCancelBtn    : NSButton!
    @IBOutlet weak var touchBarOkBtn        : NSButton!
    
    @IBOutlet weak var textFieldOriginX  : NSTextField!
    @IBOutlet weak var textFieldOriginY  : NSTextField!
    @IBOutlet weak var textFieldWidth    : NSTextField!
    @IBOutlet weak var textFieldHeight   : NSTextField!
    @IBOutlet weak var textFieldOppositeX: NSTextField!
    @IBOutlet weak var textFieldOppositeY: NSTextField!
    @IBOutlet weak var textFieldError    : NSTextField!
    
    @IBOutlet weak var previewImageView  : PreviewImageView!
    @IBOutlet weak var previewOverlayView: PreviewOverlayView!
    
    @IBOutlet weak var heightConstraint     : NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadPreviewState(animated: false)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        undoManager?.disableUndoRegistration()
        setupPreviewIfNeeded()
        updateDisplay(nil, with: contentItem)
        if isAdd {
            box.title = NSLocalizedString("New Area", comment: "EditAreaController")
        } else {
            box.title = NSLocalizedString("Edit Area", comment: "EditAreaController")
            validateInputs(view)
        }
        undoManager?.enableUndoRegistration()
        
        if let undoManager = undoManager, undoToken == nil && redoToken == nil {
            undoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidUndoChange, object: undoManager)
            { [unowned self] (notification) in
                self.validateInputs(nil)
            }
            redoToken = NotificationCenter.default.observe(name: NSNotification.Name.NSUndoManagerDidRedoChange, object: undoManager)
            { [unowned self] (notification) in
                self.validateInputs(nil)
            }
        }
    }
    
    private var lastDisplayedArea: PixelArea?
    
    private var currentRectangle: PixelRect {
        if textFieldOriginX.stringValue.isEmpty || textFieldOriginY.stringValue.isEmpty || textFieldWidth.stringValue.isEmpty || textFieldHeight.stringValue.isEmpty {
            return .null
        }
        return PixelRect(
            x: textFieldOriginX.integerValue,
            y: textFieldOriginY.integerValue,
            width: textFieldWidth.integerValue,
            height: textFieldHeight.integerValue
        )
    }
    
    private func updateDisplay(_ sender: Any?, with item: ContentItem?, isRegistered registered: Bool = false) {
        guard let pixelArea = item as? PixelArea else { return }
        
        let rect = pixelArea.rect
        textFieldOriginX  .stringValue = String(rect.minX)
        textFieldOriginY  .stringValue = String(rect.minY)
        textFieldWidth    .stringValue = String(rect.width)
        textFieldHeight   .stringValue = String(rect.height)
        textFieldOppositeX.stringValue = String(rect.maxX)
        textFieldOppositeY.stringValue = String(rect.maxY)
        
        if let lastDisplayedArea = lastDisplayedArea, lastDisplayedArea.rect != pixelArea.rect, sender != nil
        {
            undoManager?.registerUndo(withTarget: self, handler: { (targetSelf) in
                if let field = sender as? NSTextField, targetSelf.firstResponder != field
                {
                    targetSelf.makeFirstResponder(field)
                } else {
                    targetSelf.makeFirstResponder(nil)
                }
                targetSelf.updateDisplay(sender, with: lastDisplayedArea, isRegistered: true)
            })
            if !registered {
                undoManager?.setActionName(NSLocalizedString("Edit Area", comment: "updateDisplay(_:with:isRegistered:)"))
            }
        }
        
        updatePreview(to: rect.toCGRect())
        if sender != nil {
            lastDisplayedArea = pixelArea
        }
    }
    
    private func testContentItem(fromOpposite: Bool, with item: ContentItem? = nil) throws -> ContentItem? {
        guard let dataSource = contentItemSource else { return nil }
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
    
    @IBAction private func validateInputs(_ sender: Any?) {
        internalValidateInputs(sender)
    }
    
    @discardableResult
    private func internalValidateInputs(_ sender: Any?) -> ContentItem? {
        do {
            let field = sender as? NSTextField
            let item = try testContentItem(fromOpposite: field == textFieldOppositeX || field == textFieldOppositeY)
            updateDisplay(sender, with: item)
            
            let okEnabled = (item != contentItem)
            okBtn.isEnabled = okEnabled
            touchBarOkBtn.isEnabled = okEnabled
            
            textFieldError.isHidden = true
            return item
        } catch {
            resetPreview()
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
        UserDefaults.standard[.togglePreviewArea] = (sender.state == .off)
        reloadPreviewState(animated: true) { [weak self] (hidden) in
            guard let self = self else { return }
            self.setupPreviewIfNeeded()
            if !hidden {
                self.updatePreview(to: self.currentRectangle.toCGRect())
            }
        }
    }
    
    private func reloadPreviewState(animated: Bool, completionHandler: ((_ isHidden: Bool) -> Void)? = nil) {
        let previewOff: Bool = !UserDefaults.standard[.togglePreviewArea]
        let shouldAnimate = (previewBox.isHidden != previewOff)
        self.toggleBtn.state = previewOff ? .on : .off
        self.touchBarToggleBtn.state = previewOff ? .on : .off
        if animated && shouldAnimate {
            if previewOff {
                
                self.previewBox.isHidden = true
                self.toggleBtn.isEnabled = false
                self.touchBarToggleBtn.isEnabled = false
                
                self.heightConstraint.priority = .defaultHigh
                self.heightConstraint.constant = 523.0
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    self.heightConstraint.animator().constant = 243.0
                }) { [weak self] in
                    guard let self = self else { return }
                    
                    self.toggleBtn.isEnabled = true
                    self.touchBarToggleBtn.isEnabled = true
                    
                    self.previewBox.isHidden = true
                    self.heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 500.0)
                    completionHandler?(true)
                }
                
            } else {
                
                self.previewBox.isHidden = true
                self.toggleBtn.isEnabled = false
                self.touchBarToggleBtn.isEnabled = false
                
                self.heightConstraint.priority = .defaultHigh
                self.heightConstraint.constant = 243.0
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    self.heightConstraint.animator().constant = 523.0
                }) { [weak self] in
                    guard let self = self else { return }
                    
                    self.toggleBtn.isEnabled = true
                    self.touchBarToggleBtn.isEnabled = true
                    
                    self.previewBox.isHidden = false
                    self.heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 500.0)
                    completionHandler?(false)
                }
                
            }
        } else {
            self.previewBox.isHidden = previewOff
            self.heightConstraint.constant = previewOff ? 243.0 : 523.0
            self.heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 500.0)
            completionHandler?(!previewOff)
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
    
    deinit {
        debugPrint("- [EditAreaController deinit]")
    }
    
}

extension EditAreaController: ItemPreviewResponder {
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        guard let image = image else { return }
        guard let origRect = (internalValidateInputs(nil) as? PixelArea)?.rect else { return }
        
        let imageBounds = image.bounds
        let point = coordinate.toCGPoint()
        let replRect = PixelRect(
            CGRect(
                x: point.x - CGFloat(origRect.width) / 2.0,
                y: point.y - CGFloat(origRect.height) / 2.0,
                width: CGFloat(origRect.width),
                height: CGFloat(origRect.height)
            )
        ).intersection(imageBounds)
        
        makeFirstResponder(nil)
        updateDisplay(nil, with: image.area(at: replRect))
        internalValidateInputs(sender)
    }
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) { }
    
}
