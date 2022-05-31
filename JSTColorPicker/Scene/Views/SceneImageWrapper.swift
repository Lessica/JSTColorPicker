//
//  SceneImageWrapper.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class SceneImageWrapper: NSView {
    
    weak var rulerViewClient: RulerViewClient?
    var pixelBounds: PixelRect
    
    lazy var imageView: SceneImageView = {
        let view = SceneImageView()
        view.isHidden = true
        return view
    }()
    
    lazy var maskImageView: SceneImageView = {
        let mask = SceneImageView()
        mask.isHidden = true
        return mask
    }()
    
    var isInComparisonMode: Bool {
        return !maskImageView.isHidden
    }
    
    init(pixelBounds: PixelRect) {
        self.pixelBounds = pixelBounds
        super.init(frame: pixelBounds.toCGRect())
        addSubview(imageView)
        addSubview(maskImageView)
    }
    
    func setImage(_ image: PixelImage?) {
        if let image = image {
            imageView.setImage(image.cgImage, size: image.size.toCGSize())
            imageView.isHidden = false
        }
        else {
            imageView.reset()
            imageView.frame = .zero
            imageView.isHidden = true
        }
    }
    
    func setMaskImage(_ image: JSTPixelImage?) {
        if let image = image {
            maskImageView.setImage(image.toSystemImage(), size: image.size)
            maskImageView.isHidden = false
        }
        else {
            maskImageView.reset()
            maskImageView.frame = .zero
            maskImageView.isHidden = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    override var isOpaque: Bool { return true }
    
    override func rulerView(_ ruler: NSRulerView, shouldAdd marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldAdd: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, shouldMove marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldMove: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, shouldRemove marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldRemove: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, willMove marker: NSRulerMarker, toLocation location: CGFloat) -> CGFloat {
        return CGFloat(rulerViewClient?.rulerView(ruler as? RulerView, willMove: marker as! RulerMarker, toLocation: Int(round(location))) ?? Int(round(location)))
    }
    
    override func rulerView(_ ruler: NSRulerView, didAdd marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didAdd: marker as! RulerMarker)
    }
    
    override func rulerView(_ ruler: NSRulerView, didMove marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didMove: marker as! RulerMarker)
    }
    
    override func rulerView(_ ruler: NSRulerView, didRemove marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didRemove: marker as! RulerMarker)
    }
    
    private var _magnificationBeforeSmartMagnification: CGFloat? = nil
    
    override func rectForSmartMagnification(at location: NSPoint, in visibleRect: NSRect) -> NSRect {
        guard let scrollView = enclosingScrollView as? SceneScrollView else {
            return .zero
        }
        
        let epsilon = 0.05
        let upperRect = scrollView.bounds
        let currentMagnification = scrollView.wrapperRestrictedMagnification
        
        var targetMagnification: CGFloat
        let maxMagnification: CGFloat = UserDefaults.standard[.sceneMaximumSmartMagnification]
        if abs(currentMagnification - maxMagnification) < epsilon {
            if let magnificationBeforeSmartMagnification = _magnificationBeforeSmartMagnification {
                
                // smart recover
                _magnificationBeforeSmartMagnification = nil
                targetMagnification = magnificationBeforeSmartMagnification
            } else {
                targetMagnification = 1.0
            }
        }
        else if currentMagnification > maxMagnification {
            
            // zoom out
            _magnificationBeforeSmartMagnification = nil
            targetMagnification = maxMagnification
        }
        else if currentMagnification < 1.0 && abs(currentMagnification - 1.0) > epsilon {
            
            // zoom in
            _magnificationBeforeSmartMagnification = nil
            targetMagnification = 1.0
        }
        else {
            
            // smart zoom in
            _magnificationBeforeSmartMagnification = currentMagnification
            targetMagnification = maxMagnification
        }
        
        let centerPoint = location
        let targetWidth = upperRect.width / targetMagnification
        let targetHeight = upperRect.height / targetMagnification
        return CGRect(
            x: centerPoint.x - targetWidth / 2,
            y: centerPoint.y - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
    }
    
}
