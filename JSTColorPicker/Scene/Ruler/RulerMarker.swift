//
//  RulerMarker.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/11/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum RulerMarkerType {
    case horizontal
    case vertical
}

enum RulerMarkerPosition {
    case origin
    case opposite
}

class RulerMarker: NSRulerMarker {
    
    static let markerSize       = CGSize(width: 10.0, height: 10.0)
    static let placeholderImage = NSImage(color: .clear, size: RulerMarker.markerSize)
    static let horizontalOrigin = CGPoint(x: RulerMarker.markerSize.width / 2.0, y: 0.0)
    static let verticalOrigin   = CGPoint(x: RulerMarker.markerSize.width, y: RulerMarker.markerSize.height / 2.0)
    
    static func horizontalImage(with fillColor: NSColor? = nil) -> NSImage {
        let size = RulerMarker.markerSize
        return NSImage(size: size, flipped: false) { (rect) -> Bool in
            let fixedRect = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: fixedRect.midX, y: fixedRect.minY))
            path.line(to: NSPoint(x: fixedRect.maxX, y: fixedRect.maxY))
            path.line(to: NSPoint(x: fixedRect.minX, y: fixedRect.maxY))
            path.close()
            if let fillColor = fillColor {
                fillColor.setFill()
                path.fill()
            }
            NSColor.labelColor.setStroke()
            path.stroke()
            return true
        }
    }
    static func verticalImage(with fillColor: NSColor? = nil) -> NSImage {
        let size = RulerMarker.markerSize
        return NSImage(size: size, flipped: false) { (rect) -> Bool in
            let fixedRect = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath()
            path.move(to: NSPoint(x: fixedRect.maxX, y: fixedRect.midY))
            path.line(to: NSPoint(x: fixedRect.minX, y: fixedRect.maxY))
            path.line(to: NSPoint(x: fixedRect.minX, y: fixedRect.minY))
            path.close()
            if let fillColor = fillColor {
                fillColor.setFill()
                path.fill()
            }
            NSColor.labelColor.setStroke()
            path.stroke()
            return true
        }
    }
    
    public var type: RulerMarkerType = .horizontal
    public var position: RulerMarkerPosition = .origin
    public var coordinate: PixelCoordinate = .null
    public weak var annotator: Annotator?
    
    override init(rulerView ruler: NSRulerView, markerLocation location: CGFloat, image: NSImage, imageOrigin: NSPoint) {
        super.init(rulerView: ruler, markerLocation: location, image: image, imageOrigin: imageOrigin)
        isMovable = true
        isRemovable = true
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension RulerMarker {
    override var description: String {
        guard let annotator = annotator else { return "" }
        return "[RulerMarker \(annotator)->\(coordinate).\(type)]"
    }
}
