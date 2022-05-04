//
//  ContentOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/29.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class ContentOverlayView: NSView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .scaleAxesIndependently
    }
    
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // disable user interactions
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    internal var tableRowHeight: CGFloat = 20.0 {
        didSet {
            needsDisplay = true
        }
    }
    
    internal var highlightedRects: [CGRect]? {
        didSet {
            needsDisplay = true
        }
    }
    
    private static let focusLineWidth: CGFloat = 2.0
    private static let focusLineColor = NSColor(name: "focusLineColor") { appearance in
        if appearance.isLight {
            return .controlAccentColor
        }
        return .white
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard !inLiveResize else { return }
        guard let rects = highlightedRects else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.setLineWidth(Self.focusLineWidth)
        ctx.setStrokeColor(Self.focusLineColor.cgColor)
        
        let outerRect = dirtyRect
            .insetBy(dx: 0.0, dy: 0.5)
            .offsetBy(dx: 0.0, dy: 0.5)
        for rect in rects.filter({ outerRect.intersects($0) }) {
            let innerRect = rect.intersection(outerRect)
            if innerRect.height > tableRowHeight + 2.0 {
                ctx.addRect(innerRect.insetBy(dx: Self.focusLineWidth, dy: Self.focusLineWidth + 0.5))
            } else {
                ctx.addRect(rect.insetBy(dx: Self.focusLineWidth, dy: Self.focusLineWidth + 0.5))
            }
        }
        
        ctx.strokePath()
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsDisplay = true
    }
}
