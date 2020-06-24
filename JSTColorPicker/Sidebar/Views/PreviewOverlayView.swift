//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView {
    
    public weak var overlayDelegate: ItemPreviewResponder?
    
    public var imageSize: CGSize = CGSize.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    public var imageArea: CGRect {
        return CGRect(origin: .zero, size: imageSize).aspectFit(in: bounds).intersection(visibleRect)
    }
    
    public var imageScale: CGFloat {
        return CGRect(origin: .zero, size: imageSize).scaleToAspectFit(in: bounds)
    }
    
    public var highlightArea: CGRect = CGRect.zero {
        didSet {
            setNeedsDisplay(bounds)
        }
    }
    
    private static let defaultOverlayColor      : CGColor = NSColor(white: 0.0, alpha: 0.5).cgColor
    private static let defaultOverlayBorderColor: CGColor = NSColor(white: 0.0, alpha: 0.7).cgColor
    private static let defaultOverlayBorderWidth: CGFloat = 1.0
    private static let minimumOverlayRadius     : CGFloat = 3.0
    private static let minimumOverlayDiameter   : CGFloat = minimumOverlayRadius * 2
    private var trackingArea: NSTrackingArea?
    
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layerContentsPlacement = .center
    }
    
    private func createTrackingArea() {
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
        guard !inLiveResize
            && !highlightArea.isEmpty else
        {
            ctx.setFillColor(PreviewOverlayView.defaultOverlayColor)
            ctx.addRect(bounds)
            ctx.fillPath()
            return
        }
        
        let isSmallArea = highlightArea.width < PreviewOverlayView.minimumOverlayDiameter || highlightArea.height < PreviewOverlayView.minimumOverlayDiameter
        
        // fill background
        ctx.setFillColor(PreviewOverlayView.defaultOverlayColor)
        if !isSmallArea {
            ctx.addRect(highlightArea.insetBy(dx: PreviewOverlayView.defaultOverlayBorderWidth, dy: PreviewOverlayView.defaultOverlayBorderWidth))
        } else {
            ctx.addEllipse(in: CGRect(at: highlightArea.center, radius: PreviewOverlayView.minimumOverlayRadius))
        }
        ctx.addRect(bounds)
        ctx.fillPath(using: .evenOdd)
        
        // stroke border
        ctx.setLineWidth(PreviewOverlayView.defaultOverlayBorderWidth)
        ctx.setStrokeColor(PreviewOverlayView.defaultOverlayBorderColor)
        if !isSmallArea {
            ctx.addRect(highlightArea.insetBy(dx: PreviewOverlayView.defaultOverlayBorderWidth, dy: PreviewOverlayView.defaultOverlayBorderWidth))
        } else {
            ctx.addEllipse(in: CGRect(at: highlightArea.center, radius: PreviewOverlayView.minimumOverlayRadius))
        }
        ctx.strokePath()
        
    }
    
    private func mouseInside() -> Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRect.contains(loc) {
                return true
            }
        }
        return false
    }
    
    private func updateCursorAppearance() {
        guard overlayDelegate != nil else { return }
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
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsDisplay = true
    }
    
}
