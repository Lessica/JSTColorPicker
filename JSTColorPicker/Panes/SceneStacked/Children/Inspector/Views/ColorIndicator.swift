//
//  ColorIndicator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class ColorIndicator: NSControl {
    
    var color: NSColor = .clear {
        didSet {
            setImage(NSImage(color: color, size: bounds.size), size: bounds.size)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let area = NSTrackingArea.init(rect: bounds, options: [.activeInKeyWindow, .cursorUpdate], owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    
    override func mouseUp(with event: NSEvent) {
        if let action = action {
            NSApp.sendAction(action, to: self.target, from: self)
        }
    }
    
    override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }
    override var isOpaque: Bool { return true }
    
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
        layer!.borderWidth = 0.6
        layer!.cornerRadius = 5
    }
    
    func setImage(_ image: CGImage) {
        layer!.contents = image
    }
    
    func setImage(_ image: NSImage) {
        layer!.contents = image
    }
    
    func setImage(_ image: CGImage, size: CGSize) {
        setFrameSize(size)
        layer!.contents = image
    }
    
    func setImage(_ image: NSImage, size: CGSize) {
        setFrameSize(size)
        layer!.contents = image
    }
    
    func reset() {
        layer!.contents = nil
    }

    override func updateLayer() {
        super.updateLayer()
        layer!.borderColor = NSColor.gray.cgColor
    }
    
}
