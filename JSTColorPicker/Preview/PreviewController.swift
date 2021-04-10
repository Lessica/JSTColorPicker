//
//  PreviewController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class PreviewController: NSViewController, PaneController {
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-image-preview")
    
    weak var screenshot                          : Screenshot?
    var previewStage                             : ItemPreviewStage = .none
    public weak var overlayDelegate              : ItemPreviewResponder!

    @IBOutlet weak var paneBox                   : NSBox!
    @IBOutlet weak var previewImageView          : PreviewImageView!
    @IBOutlet weak var previewOverlayView        : PreviewOverlayView!
    @IBOutlet weak var previewSlider             : NSSlider!
    @IBOutlet weak var previewSliderBgView       : NSView!
    @IBOutlet weak var previewSliderLabel        : NSTextField!
    @IBOutlet weak var noImageHintLabel          : NSTextField!

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

        previewOverlayView.overlayDelegate = self
        previewSliderLabel.textColor = .white
        previewSlider.isEnabled = false
        noImageHintLabel.isHidden = false

        reloadPane()
    }
    
    private var isViewHidden: Bool = true
    
    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        ensureOverlayBounds(to: lastStoredRect, magnification: lastStoredMagnification)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }
}

extension PreviewController: ScreenshotLoader {
    var isPaneHidden: Bool  { view.isHiddenOrHasHiddenAncestor || isViewHidden }
    var isPaneStacked: Bool { true }

    func load(_ screenshot: Screenshot) throws {
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

    func reloadPane() {
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
        overlayDelegate.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        overlayDelegate.previewAction(sender, atRelativePosition: position, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        overlayDelegate.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }

    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        overlayDelegate.previewAction(sender, toMagnification: magnification)
    }
}
