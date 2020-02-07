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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addSubview(draggingOverlay)
    }
    
    weak var trackingDelegate: SceneTracking?
    weak var trackingToolDelegate: TrackingToolDelegate?
    var trackingTool: TrackingTool = .cursor {
        didSet {
            updateCursorAppearance()
        }
    }
    var shouldPerformDragMoveEvents: Bool {
        return trackingTool == .move
    }
    var shouldPerformDragAreaEvents: Bool {
        return trackingTool == .cursor || trackingTool == .magnify
    }
    
    var isBeingManipulated: Bool = false
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    
    fileprivate var previousTrackingCoordinate = PixelCoordinate.invalid
    
    fileprivate func trackAreaChanged(with event: NSEvent) {
        if !(isBeingDragged && shouldPerformDragMoveEvents) {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if wrapper.bounds.contains(loc) {
                let currentCoordinate = PixelCoordinate(loc)
                if currentCoordinate != previousTrackingCoordinate {
                    previousTrackingCoordinate = currentCoordinate
                    trackingDelegate?.trackColorChanged(self, at: currentCoordinate)
                }
            }
        }
        if isBeingDragged && shouldPerformDragAreaEvents {
            let rect = convert(draggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
            if !rect.isNull {
                let draggingArea = PixelRect(rect)
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func trackMouseDragged(with event: NSEvent) {
        let draggingArea = PixelRect(convert(draggingOverlay.frame, to: wrapper))
        if draggingArea.size > PixelSize(width: 1, height: 1) {
            if trackingTool == .cursor {
                trackingDelegate?.trackCursorDragged(self, to: draggingArea)
            }
            else if trackingTool == .magnify {
                trackingDelegate?.trackMagnifyToolDragged(self, to: draggingArea)
            }
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
        let trackingArea = NSTrackingArea.init(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
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
    
    fileprivate lazy var draggingOverlay: SceneDraggingOverlay = {
        let view = SceneDraggingOverlay()
        view.wantsLayer = false
        view.isHidden = true
        return view
    }()
    
    fileprivate var beginDraggingLocation = CGPoint.zero
    var isBeingDragged = false
    
    fileprivate func updateDraggingLayerAppearance() {
        if isBeingManipulated {
            if shouldPerformDragAreaEvents {
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
        let rect = CGRect(origin: origin, size: size).intersection(bounds)
        draggingOverlay.frame = rect
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        isBeingManipulated = true
        isBeingDragged = false
        beginDraggingLocation = convert(event.locationInWindow, from: nil)
        trackAreaChanged(with: event)
        updateDraggingLayerAppearance()
        updateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if isBeingManipulated {
            isBeingManipulated = false
            isBeingDragged = false
            trackAreaChanged(with: event)
            trackMouseDragged(with: event)
        } else {
            trackAreaChanged(with: event)
        }
        updateDraggingLayerAppearance()
        updateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(beginDraggingLocation) > SceneScrollView.minimumDraggingDistance {
            isBeingDragged = true
        }
        
        if trackingTool == .move {
            let origin = contentView.bounds.origin
            let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
            contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
        }
        else if shouldPerformDragAreaEvents {
            updateDraggingLayerBounds(at: convert(event.locationInWindow, from: nil))
        }
        
        trackAreaChanged(with: event)
        updateCursorAppearance()
    }
    
}
