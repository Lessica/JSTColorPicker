//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView {
    
    var highlightArea: CGRect = CGRect.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    static let overlayColor: CGColor = NSColor(white: 0.0, alpha: 0.5).cgColor

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // fill background
        ctx.setFillColor(PreviewOverlayView.overlayColor)
        ctx.addRect(highlightArea)
        ctx.addRect(bounds)
        ctx.fillPath(using: .evenOdd)
        
        // stroke border
        ctx.setLineCap(.square)
        ctx.setLineWidth(0.75)
        ctx.setStrokeColor(.black)
        ctx.addRect(highlightArea)
        ctx.drawPath(using: .stroke)
    }
    
}
