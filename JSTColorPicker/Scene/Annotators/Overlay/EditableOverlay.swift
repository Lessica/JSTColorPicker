//
//  EditableOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class EditableOverlay: Overlay {
    
    // MARK: - Attributes
    
    enum Direction {
        
        case none
        case northSouth
        case eastWest
        case northWestSouthEast
        case northEastSouthWest
        
    }

    enum Edge {
        
        case none
        case topLeft
        case topMiddle
        case topRight
        case middleLeft
        case middleRight
        case bottomLeft
        case bottomMiddle
        case bottomRight
        
        public var direction: Direction {
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
        
        public var isCorner: Bool { self == .topLeft   || self == .topRight   || self == .bottomLeft  || self == .bottomRight  }
        public var isMiddle: Bool { self == .topMiddle || self == .middleLeft || self == .middleRight || self == .bottomMiddle }
        
    }
    
    public var isEditing             : Bool = false
    public var editingEdge           : Edge { return isEditing ? internalEditingEdge : .none }
    private var internalEditingEdge  : Edge = .none
    public var hidesDuringEditing    : Bool { false }
    public func setEditing(at point: CGPoint) { internalEditingEdge = edge(at: point) }
    
    private static let defaultCircleRadius        : CGFloat = 4.67
    private static let defaultCircleBorderWidth   : CGFloat = 1.67
    private static let minimumSizeForMiddleCircle = CGSize(
        width: (defaultCircleRadius + defaultCircleBorderWidth) * 6.0,
        height: (defaultCircleRadius + defaultCircleBorderWidth) * 6.0
    )
    
    public var circleFillColorNormal                     : CGColor?
    public var circleFillColorHighlighted                : CGColor?
    public var circleStrokeColor                         : CGColor?
    private var internalCircleFillColorNormal            : CGColor { circleFillColorNormal      ?? EditableOverlay.defaultCircleFillColorNormal      }
    private var internalCircleFillColorHighlighted       : CGColor { circleFillColorHighlighted ?? EditableOverlay.defaultCircleFillColorHighlighted }
    private var internalCircleStrokeColor                : CGColor { circleStrokeColor          ?? EditableOverlay.defaultCircleStrokeColor          }
    private static let defaultCircleFillColorNormal      : CGColor = NSColor.systemGray.cgColor
    private static let defaultCircleFillColorHighlighted : CGColor = NSColor.systemBlue.cgColor
    private static let defaultCircleStrokeColor          : CGColor = CGColor.white
    
    private static let defaultOuterInsets = NSEdgeInsets(
        top:    -defaultCircleRadius - defaultCircleBorderWidth,
        left:   -defaultCircleRadius - defaultCircleBorderWidth,
        bottom: -defaultCircleRadius - defaultCircleBorderWidth,
        right:  -defaultCircleRadius - defaultCircleBorderWidth
    )
    private static let defaultInnerInsets = NSEdgeInsets(
        top:    defaultCircleRadius + defaultCircleBorderWidth,
        left:   defaultCircleRadius + defaultCircleBorderWidth,
        bottom: defaultCircleRadius + defaultCircleBorderWidth,
        right:  defaultCircleRadius + defaultCircleBorderWidth
    )
    
    public func direction(at point: CGPoint) -> Direction {
        guard isBordered && isEditing else { return .none }
        return edge(at: point).direction
    }
    
    public func edge(at point: CGPoint) -> Edge {
        guard isBordered && isEditing else { return .none }
        let edgeRadius = EditableOverlay.defaultCircleRadius + EditableOverlay.defaultCircleBorderWidth
        let drawBounds = bounds.inset(by: innerInsets)
             if CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomLeft }
        else if CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomRight }
        else if CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topRight }
        else if CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topLeft }
             else if drawBounds.width  > EditableOverlay.minimumSizeForMiddleCircle.width  && CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.minY), radius: edgeRadius).contains(point) { return .bottomMiddle }
             else if drawBounds.width  > EditableOverlay.minimumSizeForMiddleCircle.width  && CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.maxY), radius: edgeRadius).contains(point) { return .topMiddle    }
             else if drawBounds.height > EditableOverlay.minimumSizeForMiddleCircle.height && CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.midY), radius: edgeRadius).contains(point) { return .middleLeft   }
             else if drawBounds.height > EditableOverlay.minimumSizeForMiddleCircle.height && CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.midY), radius: edgeRadius).contains(point) { return .middleRight  }
        return .none
    }
    
    private func rectsForDrawBounds(_ drawBounds: CGRect) -> [CGRect] {
        var rects = [
            CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.minY), radius: EditableOverlay.defaultCircleRadius),
            CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.minY), radius: EditableOverlay.defaultCircleRadius),
            CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.maxY), radius: EditableOverlay.defaultCircleRadius),
            CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.maxY), radius: EditableOverlay.defaultCircleRadius),
        ]
        if drawBounds.width > EditableOverlay.minimumSizeForMiddleCircle.width {
            rects.append(contentsOf: [
                CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.minY), radius: EditableOverlay.defaultCircleRadius),
                CGRect(at: CGPoint(x: drawBounds.midX, y: drawBounds.maxY), radius: EditableOverlay.defaultCircleRadius),
            ])
        }
        if drawBounds.height > EditableOverlay.minimumSizeForMiddleCircle.height {
            rects.append(contentsOf: [
                CGRect(at: CGPoint(x: drawBounds.minX, y: drawBounds.midY), radius: EditableOverlay.defaultCircleRadius),
                CGRect(at: CGPoint(x: drawBounds.maxX, y: drawBounds.midY), radius: EditableOverlay.defaultCircleRadius),
            ])
        }
        return rects
    }
    
    override var borderStyle: Overlay.BorderStyle { isEditing ? .dashed : .solid }
    
    override var outerInsets: NSEdgeInsets {
        if isBordered && isEditing {
            return EditableOverlay.defaultOuterInsets
        }
        return super.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        if isBordered && isEditing {
            return EditableOverlay.defaultInnerInsets
        }
        return super.innerInsets
    }
    
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard isBordered && isEditing else { return }
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isEmpty else { return }
        
        let drawRects = rectsForDrawBounds(drawBounds).filter({ needsToDraw($0) })
        guard drawRects.count > 0 else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.saveGState()
        
        drawRects.forEach({ ctx.addEllipse(in: $0) })
        
        ctx.setLineWidth(EditableOverlay.defaultCircleBorderWidth)
        if isFocused || isSelected { ctx.setFillColor(internalCircleFillColorHighlighted) }
        else { ctx.setFillColor(internalCircleFillColorNormal) }
        ctx.setStrokeColor(internalCircleStrokeColor)
        ctx.drawPath(using: .fillStroke)
        
        ctx.restoreGState()
    }
    
}

