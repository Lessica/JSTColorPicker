//
//  SceneImageView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneImageView: NSView {
    
    override func hitTest(_ point: NSPoint) -> NSView? { return nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = true
        layer?.magnificationFilter = .nearest
        layerContentsRedrawPolicy = .never
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
