//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension CALayer {
    
    func bringToFront() {
        guard let sLayer = superlayer else {
            return
        }
        removeFromSuperlayer()
        sLayer.insertSublayer(self, at: UInt32(sLayer.sublayers?.count ?? 0))
    }
    
    func sendToBack() {
        guard let sLayer = superlayer else {
            return
        }
        removeFromSuperlayer()
        sLayer.insertSublayer(self, at: 0)
    }
    
}

extension CATransaction {
    
    class func withDisabledActions<T>(_ body: () throws -> T) rethrows -> T {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer {
            CATransaction.commit()
        }
        return try body()
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = true
        layer?.addSublayer(draggingLayer)
    }
    
    weak var trackingDelegate: SceneTracking?
    weak var trackingToolDelegate: TrackingToolDelegate?
    var trackingTool: TrackingTool = .cursor {
        didSet {
            updateCursorAppearance()
        }
    }
    var isBeingManipulated: Bool = false
    
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    
    fileprivate var previousTrackingCoordinate = PixelCoordinate.invalid
    
    fileprivate func mouseTrackingEvent(with event: NSEvent) {
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        guard wrapper.bounds.contains(loc) else { return }
        let currentCoordinate = PixelCoordinate(loc)
        if currentCoordinate != previousTrackingCoordinate {
            previousTrackingCoordinate = currentCoordinate
            trackingDelegate?.mousePositionChanged(self, to: currentCoordinate)
        }
    }
    
    fileprivate func mouseManipulatingEvent(with event: NSEvent) {
        let draggingArea = PixelRect(convert(draggingLayer.frame, to: wrapper))
        if draggingArea.size > PixelSize(width: 1, height: 1) {
            trackingDelegate?.mouseDraggingAreaChanged(self, to: draggingArea)
        }
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
    
    fileprivate func resetCursorDisplay() {
        NSCursor.arrow.set()
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
    
    fileprivate func createTrackingArea() {
        let trackingArea = NSTrackingArea.init(rect: visibleRect, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
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
        mouseTrackingEvent(with: event)
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        mouseTrackingEvent(with: event)
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        mouseTrackingEvent(with: event)
        resetCursorDisplay()
    }
    
    fileprivate lazy var draggingLayer: CALayer = {
        let layer = SceneDraggingOverlay()
        layer.backgroundColor = NSColor(white: 1.0, alpha: 0.2).cgColor
        layer.borderColor = .white
        layer.borderWidth = 0.667
        layer.isHidden = true
        return layer
    }()
    
    fileprivate var beginDraggingLocation = CGPoint.zero
    var isBeingDragged = false
    
    fileprivate func updateDraggingLayerAppearance() {
        if isBeingManipulated {
            CATransaction.withDisabledActions {
                draggingLayer.frame = CGRect.zero
            }
            draggingLayer.bringToFront()
            draggingLayer.isHidden = false
        } else {
            draggingLayer.isHidden = true
            draggingLayer.sendToBack()
        }
    }
    
    fileprivate func updateDraggingLayerBounds(at endDraggingLocation: CGPoint) {
        let origin = CGPoint(x: min(beginDraggingLocation.x, endDraggingLocation.x), y: min(beginDraggingLocation.y, endDraggingLocation.y))
        let size = CGSize(width: abs(endDraggingLocation.x - beginDraggingLocation.x), height: abs(endDraggingLocation.y - beginDraggingLocation.y))
        let rect = CGRect(origin: origin, size: size).intersection(bounds)
        CATransaction.withDisabledActions {
            draggingLayer.frame = rect
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        mouseTrackingEvent(with: event)
        
        isBeingManipulated = true
        isBeingDragged = false
        
        beginDraggingLocation = convert(event.locationInWindow, from: nil)
        
        updateCursorAppearance()
        updateDraggingLayerAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        mouseTrackingEvent(with: event)
        
        if isBeingManipulated {
            isBeingManipulated = false
            isBeingDragged = false
            mouseManipulatingEvent(with: event)
        }
        
        updateCursorAppearance()
        updateDraggingLayerAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        mouseTrackingEvent(with: event)
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(beginDraggingLocation) > SceneScrollView.minimumDraggingDistance {
            isBeingDragged = true
        }
        
        if trackingTool == .cursor {
            // TODO: crop from image
        }
        else if trackingTool == .move {
            let origin = contentView.bounds.origin
            let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
            contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        }
        else if trackingTool == .magnify {
            updateDraggingLayerBounds(at: convert(event.locationInWindow, from: nil))
        }
        
        updateCursorAppearance()
    }
    
}
