//
//  EditableOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum EditableDirection {
    case none
    case northSouth
    case eastWest
    case northWestSouthEast
    case northEastSouthWest
}

enum EditableEdge {
    case none
    case topLeft
    case topMiddle
    case topRight
    case middleLeft
    case middleRight
    case bottomLeft
    case bottomMiddle
    case bottomRight
    
    public var direction: EditableDirection {
        switch self {
        case .none:
            return .none
        case .topLeft, .bottomRight:
            return .northWestSouthEast
        case .topMiddle, .bottomMiddle:
            return .northSouth
        case .topRight, .bottomLeft:
            return .northEastSouthWest
        case .middleLeft, .middleRight:
            return .eastWest
        }
    }
    
    public var isCorner: Bool {
        return self == .topLeft || self == .topRight || self == .bottomLeft || self == .bottomRight
    }
    
    public var isMiddle: Bool {
        return self == .topMiddle || self == .middleLeft || self == .middleRight || self == .bottomMiddle
    }
}

class EditableOverlay: Overlay {
    
    public var isEditable: Bool = false
    public var editingEdge: EditableEdge { return isEditable ? internalEditingEdge : .none }
    public func setEditing(at point: CGPoint) { internalEditingEdge = edge(at: point) }
    fileprivate var internalEditingEdge: EditableEdge = .none
    
    public var hidesDuringEditing: Bool {
        return false
    }
    
    fileprivate static let circleRadius: CGFloat = 3.67
    fileprivate static let circleBorderWidth: CGFloat = 1.0
    fileprivate static let circleFillColorNormal = NSColor.systemGray.cgColor
    fileprivate static let circleFillColorFocused = NSColor.systemBlue.cgColor
    fileprivate static let circleStrokeColor = CGColor.white
    
    fileprivate static let outerInsets = NSEdgeInsets(top: -circleRadius - circleBorderWidth, left: -circleRadius - circleBorderWidth, bottom: -circleRadius - circleBorderWidth, right: -circleRadius - circleBorderWidth)
    fileprivate static let innerInsets = NSEdgeInsets(top: circleRadius + circleBorderWidth, left: circleRadius + circleBorderWidth, bottom: circleRadius + circleBorderWidth, right: circleRadius + circleBorderWidth)
    
    public func direction(at point: CGPoint) -> EditableDirection {
        guard isBordered && isEditable else { return .none }
        return edge(at: point).direction
    }
    
    public func edge(at point: CGPoint) -> EditableEdge {
        guard isBordered && isEditable else { return .none }
        let edgeRadius = EditableOverlay.circleRadius + EditableOverlay.circleBorderWidth
        let drawBounds = bounds.inset(by: innerInsets)
             if CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomLeft }
        else if CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomRight }
        else if CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topRight }
        else if CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topLeft }
        else if drawBounds.width > 16.0  && CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomMiddle }
        else if drawBounds.width > 16.0  && CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topMiddle }
        else if drawBounds.height > 16.0 && CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.midY), radius: edgeRadius).contains(point) { return .middleLeft }
        else if drawBounds.height > 16.0 && CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.midY), radius: edgeRadius).contains(point) { return .middleRight }
        return .none
    }
    
    fileprivate func rectsForDrawBounds(_ drawBounds: CGRect) -> [CGRect] {
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
        return rects
    }
    
    override var outerInsets: NSEdgeInsets {
        if isBordered && isEditable {
            return EditableOverlay.outerInsets
        }
        return super.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        if isBordered && isEditable {
            return EditableOverlay.innerInsets
        }
        return super.innerInsets
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isBordered && isEditable else { return }
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isEmpty else { return }
        
        let drawRects = rectsForDrawBounds(drawBounds).filter({ needsToDraw($0) })
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
