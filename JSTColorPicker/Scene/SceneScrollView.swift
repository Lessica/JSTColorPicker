//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSView {
    
    func bringToFront() {
        guard let sView = superview else {
            return
        }
        removeFromSuperview()
        sView.addSubview(self)
    }
    
}

extension CGPoint {
    
    func distanceTo(_ point: CGPoint) -> CGFloat {
        let deltaX = abs(x - point.x)
        let deltaY = abs(y - point.y)
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
}

class SceneScrollView: NSScrollView {
    
    static let minimumDraggingDistance: CGFloat = 3.0
    
    var isBeingManipulated: Bool = false
    var isBeingDragged = false
    fileprivate var beginDraggingLocation = CGPoint.zero
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var previousTrackingCoordinate = PixelCoordinate.null
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    weak var trackingDelegate: SceneTracking?
    weak var trackingToolDelegate: TrackingToolDelegate?
    var trackingTool: TrackingTool = .cursor {
        didSet {
            updateCursorAppearance()
        }
    }
    var visibleRectExcludingRulers: CGRect {
        let rect = visibleRect
        guard let thicknessV = verticalRulerView?.ruleThickness else { return rect }
        guard let thicknessH = horizontalRulerView?.ruleThickness else { return rect }
        guard let reversedThicknessV = verticalRulerView?.reservedThicknessForMarkers else { return rect }
        guard let reversedThicknessH = horizontalRulerView?.reservedThicknessForMarkers else { return rect }
        return CGRect(x: rect.origin.x + (thicknessH + reversedThicknessH), y: rect.origin.y + (thicknessV + reversedThicknessV), width: rect.width - (thicknessH + reversedThicknessH), height: rect.height - (thicknessV + reversedThicknessV))
    }
    
    fileprivate lazy var draggingOverlay: DraggingOverlay = {
        let view = DraggingOverlay()
        view.wantsLayer = false
        view.isHidden = true
        return view
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        SceneScrollView.rulerViewClass = RulerView.self
        backgroundColor = NSColor.init(patternImage: NSImage(named: "JSTBackgroundPattern")!)
        contentInsets = NSEdgeInsetsZero
        hasVerticalRuler = true
        hasHorizontalRuler = true
        rulersVisible = true
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic
        usesPredominantAxisScrolling = false
        
        if let rulerView = verticalRulerView {
            rulerView.measurementUnits = .points
            rulerView.ruleThickness = 17.0
            rulerView.reservedThicknessForMarkers = 16.0
            rulerView.reservedThicknessForAccessoryView = 0.0
        }
        
        if let rulerView = horizontalRulerView {
            rulerView.measurementUnits = .points
            rulerView.ruleThickness = 17.0
            rulerView.reservedThicknessForMarkers = 16.0
            rulerView.reservedThicknessForAccessoryView = 0.0
        }
        
        addSubview(draggingOverlay)
    }
    
    fileprivate func overlayPixelRect() -> PixelRect {
        let rect = convert(draggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
        guard !rect.isNull else { return PixelRect.null }
        return PixelRect(CGRect(origin: rect.origin, size: CGSize(width: ceil(ceil(rect.maxX) - floor(rect.minX)), height: ceil(ceil(rect.maxY) - floor(rect.minY)))))
    }
    
    fileprivate func shouldPerformMoveDragging(for event: NSEvent) -> Bool {
        if trackingTool == .move {
            return true
        }
        return false
    }
    
    fileprivate func shouldPerformAreaDragging(for event: NSEvent) -> Bool {
        if trackingTool == .cursor || trackingTool == .magnify {
            return event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        }
        return false
    }
    
    fileprivate func trackAreaChanged(with event: NSEvent) {
        if !(isBeingDragged && shouldPerformMoveDragging(for: event)) {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if wrapper.bounds.contains(loc) {
                let currentCoordinate = PixelCoordinate(loc)
                if currentCoordinate != previousTrackingCoordinate {
                    previousTrackingCoordinate = currentCoordinate
                    trackingDelegate?.trackColorChanged(self, at: currentCoordinate)
                }
            }
        }
        if isBeingDragged && shouldPerformAreaDragging(for: event) {
            let draggingArea = overlayPixelRect()
            if !draggingArea.isNull {
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func trackMouseDragged(with event: NSEvent) {
        guard shouldPerformAreaDragging(for: event) else { return }
        let draggingArea = overlayPixelRect()
        if draggingArea.size > PixelSize(width: 1, height: 1) {
            if trackingTool == .cursor {
                trackingDelegate?.trackCursorDragged(self, to: draggingArea)
            }
            else if trackingTool == .magnify {
                trackingDelegate?.trackMagnifyToolDragged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func mouseInside() -> Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRectExcludingRulers.contains(loc) {
                return true
            }
        }
        return false
    }
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: visibleRectExcludingRulers, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
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
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        trackAreaChanged(with: event)
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        trackAreaChanged(with: event)
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        trackAreaChanged(with: event)
        NSCursor.arrow.set()
    }
    
    fileprivate func updateCursorAppearance() {
        guard let delegate = trackingToolDelegate else { return }
        if !mouseInside() { return }
        if delegate.trackingToolEnabled(self, tool: trackingTool) {
            if !isBeingManipulated {
                trackingTool.currentCursor.set()
            } else {
                trackingTool.highlightCursor.set()
            }
        } else {
            trackingTool.disabledCursor.set()
        }
    }
    
    fileprivate func updateDraggingLayerAppearance(for event: NSEvent) {
        if isBeingManipulated {
            if shouldPerformAreaDragging(for: event) {
                draggingOverlay.frame = CGRect.zero
                draggingOverlay.bringToFront()
                draggingOverlay.isHidden = false
            }
        } else {
            draggingOverlay.isHidden = true
        }
    }
    
    fileprivate func updateDraggingLayerBounds(at endDraggingLocation: CGPoint) {
        let origin = CGPoint(x: min(beginDraggingLocation.x, endDraggingLocation.x), y: min(beginDraggingLocation.y, endDraggingLocation.y))
        let size = CGSize(width: abs(endDraggingLocation.x - beginDraggingLocation.x), height: abs(endDraggingLocation.y - beginDraggingLocation.y))
        let rect = CGRect(origin: origin, size: size).inset(by: draggingOverlay.outerInsets).intersection(bounds)
        draggingOverlay.frame = rect
    }
    
//    override func hitTest(_ point: NSPoint) -> NSView? {
//        let location = convert(point, from: superview)
//        guard visibleRectExcludingRulers.contains(location) else { return nil }
//        return super.hitTest(point)
//    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let currentLocation = convert(event.locationInWindow, from: nil)
        guard visibleRectExcludingRulers.contains(currentLocation) else { return }
        
        isBeingManipulated = true
        isBeingDragged = false
        beginDraggingLocation = currentLocation
        
        trackAreaChanged(with: event)
        
        updateDraggingLayerAppearance(for: event)
        updateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let currentLocation = convert(event.locationInWindow, from: nil)
        guard visibleRectExcludingRulers.contains(currentLocation) else { return }
        
        if isBeingManipulated {
            isBeingManipulated = false
            isBeingDragged = false
            
            trackAreaChanged(with: event)
            trackMouseDragged(with: event)
        } else {
            trackAreaChanged(with: event)
        }
        
        updateDraggingLayerAppearance(for: event)
        updateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let currentLocation = convert(event.locationInWindow, from: nil)
        guard visibleRectExcludingRulers.contains(currentLocation) else { return }
        
        if currentLocation.distanceTo(beginDraggingLocation) > SceneScrollView.minimumDraggingDistance {
            isBeingDragged = true
        }
        
        if shouldPerformMoveDragging(for: event) {
            let origin = contentView.bounds.origin
            let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
            contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        }
        else if shouldPerformAreaDragging(for: event) {
            updateDraggingLayerBounds(at: convert(event.locationInWindow, from: nil))
        }
        
        trackAreaChanged(with: event)
        updateCursorAppearance()
    }
    
}
