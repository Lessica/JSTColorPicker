//
//  ImageOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/7/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ImageOverlay: NSView {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override var acceptsFirstResponder: Bool { return false }
    override var isOpaque: Bool { return false }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setImage(_ image: CGImage) {
        layer?.contents = image
    }
    
    func setImage(_ image: NSImage) {
        layer?.contents = image
    }
    
    func setImage(_ image: CGImage, size: CGSize) {
        setFrameSize(size)
        layer?.contents = image
    }
    
    func setImage(_ image: NSImage, size: CGSize) {
        setFrameSize(size)
        layer?.contents = image
    }
    
    func reset() {
        layer?.contents = nil
    }
    
}
