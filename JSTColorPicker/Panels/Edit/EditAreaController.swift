//
//  EditAreaController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class EditAreaController: EditViewController {
    
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
            undoToken = NotificationCenter.default.observe(
                name: NSNotification.Name.NSUndoManagerDidUndoChange,
                object: undoManager
            )
            { [unowned self] (notification) in
                self.validateInputs(nil)
            }
            redoToken = NotificationCenter.default.observe(
                name: NSNotification.Name.NSUndoManagerDidRedoChange,
                object: undoManager
            )
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
            undoManager?.registerUndo(withTarget: self, handler: { (target) in
                if let field = sender as? NSTextField, target.firstResponder != field
                {
                    target.makeFirstResponder(field)
                } else {
                    target.makeFirstResponder(nil)
                }
                target.updateDisplay(sender, with: lastDisplayedArea, isRegistered: true)
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
                    if let _ = try delegate.addContentItem(of: replArea.rect, byIgnoringPopups: false) {
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
    
    private func reloadPreviewState(animated: Bool, completionHandler completion: ((_ isHidden: Bool) -> Void)? = nil) {
        
        let minimumHeightNormal  : CGFloat = 243.0
        let minimumHeightExpanded: CGFloat = 523.0
        
        let previewOff: Bool = !UserDefaults.standard[.togglePreviewArea]
        let shouldAnimate = (previewBox.isHidden != previewOff)
        self.toggleBtn.state = previewOff ? .on : .off
        self.touchBarToggleBtn.state = previewOff ? .on : .off
        
        let additionalHeight = textFieldError.isHidden ? 0.0 : textFieldError.bounds.height
        if animated && shouldAnimate {
            if previewOff {
                
                self.previewBox.isHidden = true
                self.toggleBtn.isEnabled = false
                self.touchBarToggleBtn.isEnabled = false
                self.textFieldError.alphaValue = 0.0
                
                self.heightConstraint.priority = .defaultHigh
                self.heightConstraint.constant = minimumHeightExpanded + additionalHeight
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    self.heightConstraint.animator().constant = minimumHeightNormal + additionalHeight
                }) { [weak self] in
                    guard let self = self else { return }
                    self.heightConstraint.constant = minimumHeightNormal
                    
                    self.previewBox.isHidden = true
                    self.toggleBtn.isEnabled = true
                    self.touchBarToggleBtn.isEnabled = true
                    self.textFieldError.alphaValue = 1.0
                    
                    self.heightConstraint.priority = .middle
                    completion?(true)
                }
                
            } else {
                
                self.previewBox.isHidden = true
                self.toggleBtn.isEnabled = false
                self.touchBarToggleBtn.isEnabled = false
                self.textFieldError.alphaValue = 0.0
                
                self.heightConstraint.priority = .defaultHigh
                self.heightConstraint.constant = minimumHeightNormal + additionalHeight
                
                NSAnimationContext.runAnimationGroup({ (context) in
                    self.heightConstraint.animator().constant = minimumHeightExpanded + additionalHeight
                }) { [weak self] in
                    guard let self = self else { return }
                    self.heightConstraint.constant = minimumHeightExpanded
                    
                    self.previewBox.isHidden = false
                    self.toggleBtn.isEnabled = true
                    self.touchBarToggleBtn.isEnabled = true
                    self.textFieldError.alphaValue = 1.0
                    
                    self.heightConstraint.priority = .middle
                    completion?(false)
                }
                
            }
        } else {
            
            self.previewBox.isHidden = previewOff
            self.toggleBtn.isEnabled = true
            self.touchBarToggleBtn.isEnabled = true
            self.textFieldError.alphaValue = 1.0
            
            self.heightConstraint.constant = previewOff ? 214.0 : 493.0
            self.heightConstraint.priority = .middle
            completion?(!previewOff)
            
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
        
        previewOverlayView.previewResponder = self
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
        debugPrint("\(className):\(#function)")
    }
    
}

extension EditAreaController: ItemPreviewResponder {
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        guard let image = image else { return }
        guard let origRect = (internalValidateInputs(nil) as? PixelArea)?.rect else { return }
        
        let imageBounds = image.bounds
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
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        previewAction(sender, atAbsolutePoint: coordinate.toCGPoint(), animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) { fatalError("not implemented") }
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) { fatalError("not implemented") }
    func previewActionRaw(_ sender: ItemPreviewSender?, withEvent event: NSEvent) { fatalError("not implemented") }
    
}
