//
//  OverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class Overlay: NSView {
    
    static let borderWidth: CGFloat = 1.0
    
    var isBordered: Bool {
        return false
    }
    
    var outerInsets: NSEdgeInsets {
        return NSEdgeInsets(top: -Overlay.borderWidth, left: -Overlay.borderWidth, bottom: -Overlay.borderWidth, right: -Overlay.borderWidth)
    }
    
    var innerInsets: NSEdgeInsets {
        return NSEdgeInsets(top: Overlay.borderWidth, left: Overlay.borderWidth, bottom: Overlay.borderWidth, right: Overlay.borderWidth)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isBordered else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // black-white painted dashed lines
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isNull else { return }
        
        ctx.saveGState()
        
        ctx.setLineWidth(Overlay.borderWidth)
        ctx.setStrokeColor(.black)
        ctx.stroke(drawBounds)
        
        ctx.setLineDash(phase: 0.0, lengths: [5.0, 4.0])
        ctx.setStrokeColor(.white)
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.minY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY))
        ctx.strokePath()
        
        ctx.move(to: CGPoint(x: drawBounds.minX, y: drawBounds.maxY))
        ctx.addLine(to: CGPoint(x: drawBounds.minX, y: drawBounds.minY))
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
}
