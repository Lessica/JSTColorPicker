//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView {
    
    public weak var overlayDelegate: PreviewResponder!
    
    var imageSize: CGSize = CGSize.zero {
        didSet {
            setNeedsDisplay()
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
            setNeedsDisplay()
        }
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    fileprivate static let overlayColor: CGColor = NSColor(white: 0.0, alpha: 0.5).cgColor
    fileprivate static let overlayBorderColor: CGColor = NSColor(white: 0.0, alpha: 0.7).cgColor
    fileprivate static let overlayBorderWidth: CGFloat = 1.0
    fileprivate var trackingArea: NSTrackingArea?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
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
        
        // ctx.saveGState()
        
        let insetArea = highlightArea.insetBy(dx: 1.0, dy: 1.0)
        
        // fill background
        ctx.setFillColor(PreviewOverlayView.overlayColor)
        ctx.addRect(insetArea)
        ctx.addRect(bounds)
        ctx.fillPath(using: .evenOdd)
        
        // stroke border
        ctx.setLineWidth(PreviewOverlayView.overlayBorderWidth)
        ctx.setStrokeColor(PreviewOverlayView.overlayBorderColor)
        ctx.addRect(insetArea)
        ctx.strokePath()
        
        // ctx.restoreGState()
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
        overlayDelegate.previewAction(self, centeredAt: PixelCoordinate(relLoc))
    }
    
}
