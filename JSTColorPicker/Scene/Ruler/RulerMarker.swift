//
//  RulerMarker.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/11/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

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
    
    static var horizontalImage: NSImage = {
        let size = RulerMarker.markerSize
        let image = NSImage(size: size)
        image.lockFocus()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: size.width / 2.0, y: 0.0))
        path.line(to: NSPoint(x: size.width, y: size.height))
        path.line(to: NSPoint(x: 0.0, y: size.height))
        path.close()
        NSColor.labelColor.set()
        path.fill()
        image.unlockFocus()
        return image
    }()
    static var verticalImage: NSImage = {
        let size = RulerMarker.markerSize
        let image = NSImage(size: size)
        image.lockFocus()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: size.width, y: size.height / 2.0))
        path.line(to: NSPoint(x: 0.0, y: size.height))
        path.line(to: NSPoint(x: 0.0, y: 0.0))
        path.close()
        NSColor.labelColor.set()
        path.fill()
        image.unlockFocus()
        return image
    }()
    
    var type: RulerMarkerType = .horizontal
    var position: RulerMarkerPosition = .origin
    var coordinate: PixelCoordinate = .null
    weak var annotator: Annotator?
    
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
