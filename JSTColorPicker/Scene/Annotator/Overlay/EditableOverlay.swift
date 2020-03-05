//
//  EditableOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditableOverlay: Overlay {
    
    fileprivate static let circleRadius: CGFloat = 3.67
    fileprivate static let circleBorderWidth: CGFloat = 1.0
    fileprivate static let circleFillColorNormal = NSColor.systemGray.cgColor
    fileprivate static let circleFillColorFocused = NSColor.systemBlue.cgColor
    fileprivate static let circleStrokeColor = CGColor.white
    
    public static let outerInsets = NSEdgeInsets(top: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, left: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, bottom: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth, right: -EditableOverlay.circleRadius - EditableOverlay.circleBorderWidth)
    fileprivate static let innerInsets = NSEdgeInsets(top: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, left: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, bottom: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth, right: EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth)
    
    public var isEditable: Bool {
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
        if isFocused {
            ctx.setFillColor(EditableOverlay.circleFillColorFocused)
        } else {
            ctx.setFillColor(EditableOverlay.circleFillColorNormal)
        }
        ctx.setStrokeColor(EditableOverlay.circleStrokeColor)
        
        var rects = [
            CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.minY), radius: EditableOverlay.circleRadius),
            CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.minY), radius: EditableOverlay.circleRadius),
            CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY), radius: EditableOverlay.circleRadius),
            CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.maxY), radius: EditableOverlay.circleRadius),
        ]
        
        if drawBounds.width > 16.0 {
            rects.append(contentsOf: [
                CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.minY), radius: EditableOverlay.circleRadius),
                CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.maxY), radius: EditableOverlay.circleRadius),
            ])
        }
        
        if drawBounds.height > 16.0 {
            rects.append(contentsOf: [
                CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.midY), radius: EditableOverlay.circleRadius),
                CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.midY), radius: EditableOverlay.circleRadius),
            ])
        }
        
        rects.filter({ needsToDraw($0) }).forEach({ ctx.addEllipse(in: $0) })
        ctx.drawPath(using: .fillStroke)
        ctx.restoreGState()
        
    }
    
}
