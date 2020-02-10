//
//  EditableOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class EditableOverlay: Overlay {
    
    static let circleRadius: CGFloat = 3.67
    static let circleBorderWidth: CGFloat = 1.0
    static let outerInsets = NSEdgeInsets(top: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, left: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, bottom: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, right: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth)
    static let innerInsets = NSEdgeInsets(top: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, left: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, bottom: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, right: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth)
    
    var isEditable: Bool {
        return false
    }
    
    override var outerInsets: NSEdgeInsets {
        return EditableOverlay.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        return EditableOverlay.innerInsets
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isEditable else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // draw editable anchor points
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isNull else { return }
        
        ctx.saveGState()
        
        ctx.setLineWidth(EditableOverlay.circleBorderWidth)
        ctx.setFillColor(NSColor.gray.cgColor)
        ctx.setStrokeColor(.white)
        
        let points = [
            CGPoint(x: drawBounds.minX, y: drawBounds.minY),
            CGPoint(x: drawBounds.maxX, y: drawBounds.minY),
            CGPoint(x: drawBounds.maxX, y: drawBounds.maxY),
            CGPoint(x: drawBounds.minX, y: drawBounds.maxY),
        ]
        for point in points {
            ctx.addArc(center: point, radius: EditableOverlay.circleRadius, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: true)
            ctx.drawPath(using: .fillStroke)
        }
        
        if drawBounds.width > 16.0 {
            let points = [
                CGPoint(x: drawBounds.midX, y: drawBounds.minY),
                CGPoint(x: drawBounds.midX, y: drawBounds.maxY)
            ]
            for point in points {
                ctx.addArc(center: point, radius: EditableOverlay.circleRadius, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: true)
                ctx.drawPath(using: .fillStroke)
            }
        }
        
        if drawBounds.height > 16.0 {
            let points = [
                CGPoint(x: drawBounds.minX, y: drawBounds.midY),
                CGPoint(x: drawBounds.maxX, y: drawBounds.midY)
            ]
            for point in points {
                ctx.addArc(center: point, radius: EditableOverlay.circleRadius, startAngle: 0.0, endAngle: .pi * 2.0, clockwise: true)
                ctx.drawPath(using: .fillStroke)
            }
        }
        
        ctx.restoreGState()
        
    }
    
}
