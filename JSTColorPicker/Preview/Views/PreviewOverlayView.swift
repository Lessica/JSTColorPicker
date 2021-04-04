//
//  PreviewOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

private extension CGContext {
    func drawInGState(_ callback: (CGContext) -> Void) {
        saveGState()
        callback(self)
        restoreGState()
    }
}

class PreviewOverlayView: NSView, ItemPreviewSender {
    
    weak     var overlayDelegate                  : ItemPreviewResponder?
    private  var trackingArea                     : NSTrackingArea?
    private  var isSmallArea                      : Bool { highlightArea.width < PreviewOverlayView.minimumOverlayDiameter || highlightArea.height < PreviewOverlayView.minimumOverlayDiameter }
    override var isFlipped                        : Bool { true }
    override var isOpaque                         : Bool { false }
    override var wantsDefaultClipping             : Bool { false }
    
    var imageSize                                 : CGSize = CGSize.zero { didSet { setNeedsDisplay(bounds) } }
    var imageArea                                 : CGRect               { CGRect(origin: .zero, size: imageSize).aspectFit(in: bounds).intersection(visibleRect) }
    var imageScale                                : CGFloat              { CGRect(origin: .zero, size: imageSize).scaleToAspectFit(in: bounds) }
    var highlightArea                             : CGRect = CGRect.zero { didSet { setNeedsDisplay(bounds) } }
    
    private static let defaultOverlayColor        : CGColor = NSColor(white: 0.914, alpha: 0.44).cgColor
    private static let defaultOverlayBorderColor  : CGColor = NSColor(white: 1.0, alpha: 0.5).cgColor
    private static let defaultOverlayBorderWidth  : CGFloat = 1.0
    private static let defaultOverlayShadowColor  : CGColor = .black
    
    private static let minimumOverlayRadius       : CGFloat = 3.0
    private static let minimumOverlayDiameter     : CGFloat = minimumOverlayRadius * 3
    private static let minimumDraggingDistance    : CGFloat = 3.0

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
            if imageSize != .zero {
                ctx.setFillColor(PreviewOverlayView.defaultOverlayColor)
                ctx.addRect(imageArea)
                ctx.fillPath()
            }
            return
        }

        let addHighlightPath: (CGContext) -> Void = { [unowned self] (innerCtx) in
            let highlightArea = self.highlightArea
            let highlightPath = CGPath(
                roundedRect: highlightArea
                    .insetBy(dx: PreviewOverlayView.defaultOverlayBorderWidth * 0.5, dy: PreviewOverlayView.defaultOverlayBorderWidth * 0.5)
                    .offsetBy(dx: -PreviewOverlayView.defaultOverlayBorderWidth * 0.25, dy: -PreviewOverlayView.defaultOverlayBorderWidth * 0.25),
                cornerWidth: PreviewOverlayView.minimumOverlayRadius,
                cornerHeight: PreviewOverlayView.minimumOverlayRadius,
                transform: nil
            )
            if !self.isSmallArea {
                innerCtx.addPath(highlightPath)
            } else {
                innerCtx.addEllipse(in: CGRect(at: highlightArea.center, radius: PreviewOverlayView.minimumOverlayRadius))
            }
        }

        ctx.setBlendMode(.multiply)
        ctx.setLineWidth(PreviewOverlayView.defaultOverlayBorderWidth)
        ctx.setStrokeColor(PreviewOverlayView.defaultOverlayBorderColor)
        ctx.setFillColor(PreviewOverlayView.defaultOverlayColor)

        ctx.drawInGState { innerCtx in
            innerCtx.setShadow(offset: .zero, blur: 6.0, color: PreviewOverlayView.defaultOverlayShadowColor)

            addHighlightPath(innerCtx)
            innerCtx.addRect(imageArea)
            innerCtx.clip(using: .evenOdd)

            addHighlightPath(innerCtx)
            innerCtx.strokePath()
        }

        addHighlightPath(ctx)
        ctx.addRect(imageArea)
        ctx.drawPath(using: .eoFillStroke)
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
    
    var previewStage                      : ItemPreviewStage = .none
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
