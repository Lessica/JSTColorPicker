//
//  EditableOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditableOverlay: Overlay {
    
    public var isEditable: Bool = false
    
    fileprivate static let circleRadius: CGFloat = 3.67
    fileprivate static let circleBorderWidth: CGFloat = 1.0
    fileprivate static let circleFillColorNormal = NSColor.systemGray.cgColor
    fileprivate static let circleFillColorFocused = NSColor.systemBlue.cgColor
    fileprivate static let circleStrokeColor = CGColor.white
    
    fileprivate static let outerInsets = NSEdgeInsets(top: -circleRadius - circleBorderWidth, left: -circleRadius - circleBorderWidth, bottom: -circleRadius - circleBorderWidth, right: -circleRadius - circleBorderWidth)
    fileprivate static let innerInsets = NSEdgeInsets(top: circleRadius + circleBorderWidth, left: circleRadius + circleBorderWidth, bottom: circleRadius + circleBorderWidth, right: circleRadius + circleBorderWidth)
    
    override var outerInsets: NSEdgeInsets {
        if isEditable {
            return EditableOverlay.outerInsets
        }
        return super.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        if isEditable {
            return EditableOverlay.innerInsets
        }
        return super.innerInsets
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isEditable else { return }
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isNull else { return }
        
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
        let drawRects = rects.filter({ needsToDraw($0) })
        guard drawRects.count > 0 else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.saveGState()
        
        drawRects.forEach({ ctx.addEllipse(in: $0) })
        
        ctx.setLineWidth(EditableOverlay.circleBorderWidth)
        if isFocused { ctx.setFillColor(EditableOverlay.circleFillColorFocused) }
        else { ctx.setFillColor(EditableOverlay.circleFillColorNormal) }
        ctx.setStrokeColor(EditableOverlay.circleStrokeColor)
        ctx.drawPath(using: .fillStroke)
        
        ctx.restoreGState()
        
    }
    
}
