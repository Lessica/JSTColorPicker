//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView {
    
    weak var overlayDelegate: PreviewResponder?
    
    var imageSize: CGSize = CGSize.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    var imageArea: CGRect {
        return CGRect(origin: .zero, size: imageSize).aspectFit(in: bounds).intersection(visibleRect)
    }
    
    var imageScale: CGFloat {
        return CGRect(origin: .zero, size: imageSize).scaleToAspectFit(in: bounds)
    }
    
    var highlightArea: CGRect = CGRect.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    static let overlayColor: CGColor = NSColor(white: 0.0, alpha: 0.5).cgColor
    
    fileprivate var trackingArea: NSTrackingArea?
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: imageArea, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea
    }
    
    override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        createTrackingArea()
        super.updateTrackingAreas()
    }
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        ctx.saveGState()
        
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
        
        ctx.restoreGState()
    }
    
    fileprivate func mouseInside() -> Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRect.contains(loc) {
                return true
            }
        }
        return false
    }
    
    fileprivate func updateCursorAppearance() {
        if !mouseInside() { return }
        NSCursor.pointingHand.set()
    }
    
    override func mouseEntered(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }
    
    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard imageArea.contains(loc) else { return }
        
        let relLoc = CGPoint(x: (loc.x - imageArea.minX) / imageScale, y: (loc.y - imageArea.minY) / imageScale)
        overlayDelegate?.previewAction(self, centeredAt: PixelCoordinate(relLoc))
    }
    
}
