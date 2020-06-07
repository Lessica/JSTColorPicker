//
//  PreviewImageView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewImageView: NSView {
    
    override var isOpaque: Bool { true }
    override var wantsDefaultClipping: Bool { false }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = true
        layer?.contentsGravity = .resizeAspect
        layerContentsRedrawPolicy = .never
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.isOpaque = true
        layer?.contentsGravity = .resizeAspect
        layerContentsRedrawPolicy = .never
    }
    
    public func setImage(_ image: CGImage) {
        layer?.contents = image
    }
    
    public func setImage(_ image: NSImage) {
        layer?.contents = image
    }
    
    public func setImage(_ image: CGImage, size: CGSize) {
        setFrameSize(size)
        layer?.contents = image
    }
    
    public func setImage(_ image: NSImage, size: CGSize) {
        setFrameSize(size)
        layer?.contents = image
    }
    
    public func reset() {
        layer?.contents = nil
    }
    
}
