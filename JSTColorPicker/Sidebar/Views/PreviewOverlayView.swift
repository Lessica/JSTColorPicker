//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PreviewOverlayView: NSView, ItemPreviewSender {
    
    public weak var overlayDelegate: ItemPreviewResponder?
    
    public var imageSize: CGSize = CGSize.zero {
        didSet { setNeedsDisplay(bounds) }
    }
    
    public var imageArea: CGRect {
        return CGRect(origin: .zero, size: imageSize).aspectFit(in: bounds).intersection(visibleRect)
    }
    
    public var imageScale: CGFloat {
        return CGRect(origin: .zero, size: imageSize).scaleToAspectFit(in: bounds)
    }
    
    public var highlightArea: CGRect = CGRect.zero {
        didSet { setNeedsDisplay(bounds) }
    }
    
    private static let defaultOverlayColor        : CGColor = NSColor(white: 0.0, alpha: 0.5).cgColor
    private static let defaultOverlayBorderColor  : CGColor = NSColor(white: 1.0, alpha: 0.5).cgColor
    private static let defaultOverlayBorderWidth  : CGFloat = 1.0
    
    private static let minimumOverlayRadius       : CGFloat = 3.0
    private static let minimumOverlayDiameter     : CGFloat = minimumOverlayRadius * 3
    private static let minimumDraggingDistance    : CGFloat = 3.0
    private var isSmallArea: Bool { highlightArea.width < PreviewOverlayView.minimumOverlayDiameter || highlightArea.height < PreviewOverlayView.minimumOverlayDiameter }
    
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
        let trackingArea = NSTrackingArea.init(
            rect: imageArea,
            options: [
                .mouseEnteredAndExited,
                .mouseMoved,
                .activeInKeyWindow
            ],
            owner: self,
            userInfo: nil
        )
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
        
        let highlightPath = CGPath(
            roundedRect: highlightArea
                .insetBy(dx: PreviewOverlayView.defaultOverlayBorderWidth * 0.5, dy: PreviewOverlayView.defaultOverlayBorderWidth * 0.5)
                .offsetBy(dx: -PreviewOverlayView.defaultOverlayBorderWidth * 0.25, dy: -PreviewOverlayView.defaultOverlayBorderWidth * 0.25),
            cornerWidth: PreviewOverlayView.minimumOverlayRadius,
            cornerHeight: PreviewOverlayView.minimumOverlayRadius,
            transform: nil
        )
        
        // fill background
        ctx.setFillColor(PreviewOverlayView.defaultOverlayColor)
        if !isSmallArea {
            ctx.addPath(highlightPath)
        } else {
            ctx.addEllipse(in: CGRect(at: highlightArea.center, radius: PreviewOverlayView.minimumOverlayRadius))
        }
        ctx.addRect(bounds)
        ctx.fillPath(using: .evenOdd)
        
        // stroke border
        ctx.setLineWidth(PreviewOverlayView.defaultOverlayBorderWidth)
        ctx.setStrokeColor(PreviewOverlayView.defaultOverlayBorderColor)
        if !isSmallArea {
            ctx.addPath(highlightPath)
        } else {
            ctx.addEllipse(in: CGRect(at: highlightArea.center, radius: PreviewOverlayView.minimumOverlayRadius))
        }
        ctx.strokePath()
    }
    
    private func isMouseInsideImage(with event: NSEvent) -> Bool {
        let loc = convert(event.locationInWindow, from: nil)
        return imageArea.contains(loc)
    }
    
    private func isMouseInsideHighlightArea(with event: NSEvent) -> Bool {
        guard !isSmallArea else { return false }
        let loc = convert(event.locationInWindow, from: nil)
        return highlightArea.contains(loc)
    }
    
    private func updateCursorAppearance(with event: NSEvent) {
        guard overlayDelegate != nil else { return }
        if isInDragging {
            NSCursor.closedHand.set()
        } else if isMouseInsideImage(with: event) {
            if !isMouseInsideHighlightArea(with: event) {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.openHand.set()
            }
        } else {
            NSCursor.arrow.set()
        }
    }
    
    private func resetCursorAppearance() {
        NSCursor.arrow.set()
    }
    
    override func mouseEntered(with event: NSEvent) {
        updateCursorAppearance(with: event)
    }
    
    override func mouseMoved(with event: NSEvent) {
        updateCursorAppearance(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        resetCursorAppearance()
    }
    
    private var isDirectMode              : Bool = false
    private var isDraggingMode            : Bool = false
    private var isInDragging              : Bool = false
    private var beginDraggingLocation     : CGPoint = .null
    private var beginDraggingMiddlePoint  : CGPoint = .null
    
    internal var previewStage             : ItemPreviewStage = .none
    private func preview(with event: NSEvent) {
        if isDirectMode {
            previewStage = .end
            let currentLocation = convert(event.locationInWindow, from: nil)
            guard imageArea.contains(currentLocation) else { return }
            let relLoc = CGPoint(x: (currentLocation.x - imageArea.minX) / imageScale, y: (currentLocation.y - imageArea.minY) / imageScale)
            overlayDelegate?.previewAction(self, atCoordinate: PixelCoordinate(relLoc), animated: true)
        }
        if isDraggingMode {
            if isInDragging {
                if previewStage == .none || previewStage == .end {
                    previewStage = .begin
                } else if previewStage == .begin {
                    previewStage = .inProgress
                }
            } else {
                if previewStage == .begin || previewStage == .inProgress {
                    previewStage = .end
                } else if previewStage == .end {
                    previewStage = .none
                }
            }
            
            let currentLocation = convert(event.locationInWindow, from: nil)
            let offsetSize = CGSize(width: currentLocation.x - beginDraggingLocation.x, height: currentLocation.y - beginDraggingLocation.y)
            let middleLocation = beginDraggingMiddlePoint.offsetBy(dx: offsetSize.width, dy: offsetSize.height)
            let closestLocation = imageArea.closestPoint(to: middleLocation)
            
            let relLoc = CGPoint(x: (closestLocation.x - imageArea.minX) / imageScale, y: (closestLocation.y - imageArea.minY) / imageScale)
            overlayDelegate?.previewAction(self, atAbsolutePoint: relLoc, animated: false)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let beginInside = isMouseInsideHighlightArea(with: event)
        isDirectMode = !beginInside
        isDraggingMode = beginInside
        isInDragging = beginInside
        beginDraggingLocation = convert(event.locationInWindow, from: nil)
        beginDraggingMiddlePoint = highlightArea.center
        
        if isInDragging { preview(with: event) }
        updateCursorAppearance(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard loc.distanceTo(beginDraggingLocation) > PreviewOverlayView.minimumDraggingDistance else { return }
        if isDirectMode { isDirectMode = false }
        if isDraggingMode { isInDragging = true }
        if isInDragging { preview(with: event) }
        updateCursorAppearance(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        isInDragging = false
        preview(with: event)
        updateCursorAppearance(with: event)
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        needsDisplay = true
    }
    
}
