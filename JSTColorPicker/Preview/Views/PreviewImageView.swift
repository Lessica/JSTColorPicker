//
//  PreviewImageView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewImageView: NSView {
    
    private static let defaultContentsBorderColor  : CGColor = NSColor(white: 0.914, alpha: 0.44).cgColor
    private static let defaultContentsBorderWidth  : CGFloat = 1.0
    
    override var isOpaque: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer!.isOpaque = true
        layer!.masksToBounds = false
        layer!.contentsGravity = .resizeAspect
        layer!.compositingFilter = CIFilter(name: "CIMultiplyBlendMode")
        layer!.addSublayer(borderLayer)
        layerContentsRedrawPolicy = .never
    }
    
    private func setupBorder(with size: CGSize) {
        borderLayer.frame =
            CGRect(origin: .zero, size: size)
            .aspectFit(in: layer!.bounds)
            .insetBy(dx: -PreviewImageView.defaultContentsBorderWidth * 0.5, dy: -PreviewImageView.defaultContentsBorderWidth * 0.5)
            .offsetBy(dx: -PreviewImageView.defaultContentsBorderWidth * 0.25, dy: -PreviewImageView.defaultContentsBorderWidth * 0.25)
    }
    
    public func setImage(_ image: CGImage) {
        layer!.contents = image
        setupBorder(with: CGSize(width: image.width, height: image.height))
    }
    
    public func setImage(_ image: NSImage) {
        layer!.contents = image
        setupBorder(with: image.size)
    }
    
    public func setImage(_ image: CGImage, size: CGSize) {
        setFrameSize(size)
        layer!.contents = image
        setupBorder(with: CGSize(width: image.width, height: image.height))
    }
    
    public func setImage(_ image: NSImage, size: CGSize) {
        setFrameSize(size)
        layer!.contents = image
        setupBorder(with: image.size)
    }
    
    public func reset() {
        layer!.contents = nil
        borderLayer.frame = .zero
    }
    
    private lazy var borderLayer: CALayer = {
        let layer = CALayer()
        layer.borderColor = PreviewImageView.defaultContentsBorderColor
        layer.borderWidth = PreviewImageView.defaultContentsBorderWidth
        return layer
    }()
    
}
