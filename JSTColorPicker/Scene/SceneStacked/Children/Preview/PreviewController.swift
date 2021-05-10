//
//  PreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class PreviewController: StackedPaneController {
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-image-preview") }

    var previewStage                             : ItemPreviewStage = .none
    public weak var previewResponder             : ItemPreviewResponder!

    @IBOutlet weak var previewImageView          : PreviewImageView!
    @IBOutlet weak var previewOverlayView        : PreviewOverlayView!
    @IBOutlet weak var previewSlider             : PreviewSlider!
    @IBOutlet weak var previewSliderBgView       : NSView!
    @IBOutlet weak var previewSliderLabel        : NSTextField!
    @IBOutlet weak var noImageHintLabel          : NSTextField!
    
    private        let observableKeys            : [UserDefaults.Key] = [.sceneMaximumSmartMagnification]
    private        var observables               : [Observable]?

    private var lastStoredRect                   : CGRect?
    private var lastStoredMagnification          : CGFloat?

    override func awakeFromNib() {
        super.awakeFromNib()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        lastStoredRect = nil
        lastStoredMagnification = nil

        previewOverlayView.previewResponder = self
        previewSliderLabel.textColor = .white
        previewSlider.isEnabled = false
        noImageHintLabel.isHidden = false
        
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        ensureOverlayBounds(to: lastStoredRect, magnification: lastStoredMagnification)
    }
    
    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .sceneMaximumSmartMagnification {
            previewSlider.resetMaximumSmartMagnification()
        }
    }

    override var isPaneStacked: Bool { true }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        guard let image = screenshot.image else {
            throw Screenshot.Error.invalidImage
        }

        self.screenshot = screenshot

        lastStoredRect = nil
        lastStoredMagnification = nil

        let previewSize = image.size.toCGSize()
        let previewRect = CGRect(origin: .zero, size: previewSize).aspectFit(in: previewImageView.bounds)
        let previewImage = image.downsample(to: previewRect.size, scale: NSScreen.main?.backingScaleFactor ?? 1.0)

        previewImageView.setImage(previewImage)
        previewOverlayView.imageSize = previewSize
        previewOverlayView.highlightArea = previewRect

        previewSlider.isEnabled = true
        noImageHintLabel.isHidden = true
    }

    override func reloadPane() {
        super.reloadPane()
        guard let lastStoredRect = lastStoredRect,
              let lastStoredMagnification = lastStoredMagnification else { return }
        updatePreview(to: lastStoredRect, magnification: lastStoredMagnification)
    }
}


extension PreviewController: ItemPreviewDelegate {
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
        lastStoredRect = rect
        lastStoredMagnification = magnification
        
        guard !isPaneHidden else {
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
}

extension PreviewController: ItemPreviewSender, ItemPreviewResponder {
    @IBAction private func previewSliderValueChanged(_ sender: NSSlider) {
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
        previewResponder.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        previewResponder.previewAction(sender, atRelativePosition: position, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        previewResponder.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        previewResponder.previewAction(sender, toMagnification: magnification)
    }
    
    func previewActionRaw(_ sender: ItemPreviewSender?, withEvent event: NSEvent) {
        previewResponder.previewActionRaw(sender, withEvent: event)
    }
    
}
