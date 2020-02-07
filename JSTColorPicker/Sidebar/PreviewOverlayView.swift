//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView {
    
    var imageSize: CGSize = CGSize.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
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
        let trackingRect = CGRect(origin: .zero, size: imageSize).aspectFit(in: bounds).intersection(visibleRect)
        let trackingArea = NSTrackingArea.init(rect: trackingRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
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
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
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
        super.mouseEntered(with: event)
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
    }
    
}
