//
//  SceneDraggingOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class SceneDraggingOverlay: NSView {
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // black-white painted dashed lines
        
        let drawBounds = bounds.insetBy(dx: 1.0, dy: 1.0)
        guard !drawBounds.isNull else { return }
        
        ctx.setLineWidth(1.0)
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
    }
    
}
