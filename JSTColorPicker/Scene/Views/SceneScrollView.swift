//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneScrollView: NSScrollView {
    
    public var enableForceTouch: Bool = false
    public var drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground] {
        didSet {
            reloadSceneBackground()
        }
    }
    public var drawRulersInScene: Bool = UserDefaults.standard[.drawRulersInScene] {
        didSet {
            reloadSceneRulers()
        }
    }
    fileprivate var minimumDraggingDistance: CGFloat { return enableForceTouch ? 6.0 : 3.0 }
    fileprivate func requiredEventStageFor(_ tool: SceneTool) -> Int {
        switch tool {
        case .magicCursor, .magnifyingGlass:
            return enableForceTouch ? 1 : 0
        default:
            return 0
        }
    }
    
    fileprivate static let rulerThickness: CGFloat = 16.0
    fileprivate static let reservedThicknessForMarkers: CGFloat = 15.0
    fileprivate static let reservedThicknessForAccessoryView: CGFloat = 0.0
    public var visibleRectExcludingRulers: CGRect {
        let rect = visibleRect
        return CGRect(x: rect.minX + alternativeBoundsOrigin.x, y: rect.minY + alternativeBoundsOrigin.y, width: rect.width - alternativeBoundsOrigin.x, height: rect.height - alternativeBoundsOrigin.y)
    }
    public var alternativeBoundsOrigin: CGPoint {
        if drawRulersInScene {
            return CGPoint(x: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView, y: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView)
        }
        return CGPoint.zero
    }
    public var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRectExcludingRulers.contains(loc) {
                return true
            }
        }
        return false
    }
    
    public weak var trackingDelegate: SceneTracking?
    fileprivate var wrapper: SceneImageWrapper { return documentView as! SceneImageWrapper }
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var trackingCoordinate = PixelCoordinate.null
    
    public var sceneEventObservers: [SceneEventObserver] = []
    public weak var sceneToolDataSource: SceneToolDataSource?
    fileprivate var sceneTool: SceneTool { return sceneToolDataSource!.sceneTool }
    public weak var sceneStateDataSource: SceneStateDataSource?
    fileprivate var sceneState: SceneState { return sceneStateDataSource!.sceneState }
    public weak var sceneActionEffectViewDataSource: SceneEffectViewDataSource?
    fileprivate var sceneActionEffectView: SceneEffectView { return sceneActionEffectViewDataSource!.sceneEffectView }
    
    fileprivate lazy var areaDraggingOverlay: DraggingOverlay = {
        let view = DraggingOverlay()
        view.isHidden = true
        return view
    }()
    fileprivate var areaDraggingOverlayPixelRect: PixelRect {
        let rect = sceneActionEffectView.convert(areaDraggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
        guard !rect.isEmpty else { return .null }
        return PixelRect(CGRect(origin: rect.origin, size: CGSize(width: ceil(ceil(rect.maxX) - floor(rect.minX)), height: ceil(ceil(rect.maxY) - floor(rect.minY)))))
    }
    
    fileprivate lazy var annotatorDraggingOverlay: ImageOverlay = {
        let view = ImageOverlay()
        view.alphaValue = 0.9
        view.isHidden = true
        return view
    }()
    fileprivate var annotatorDraggingOverlayPixelCoordinate: PixelCoordinate {
        let point = sceneActionEffectView.convert(annotatorDraggingOverlay.frame.center, to: wrapper)
        guard wrapper.bounds.contains(point) else { return .null }
        return PixelCoordinate(point)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        SceneScrollView.rulerViewClass = RulerView.self
        contentInsets = NSEdgeInsetsZero
        drawsBackground = true
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic
        usesPredominantAxisScrolling = UserDefaults.standard[.usesPredominantAxisScrolling]
        
        hasVerticalRuler = true
        hasHorizontalRuler = true
        if let rulerView = verticalRulerView {
            rulerView.measurementUnits = .points
            rulerView.ruleThickness = SceneScrollView.rulerThickness
            rulerView.reservedThicknessForMarkers = SceneScrollView.reservedThicknessForMarkers
            rulerView.reservedThicknessForAccessoryView = SceneScrollView.reservedThicknessForAccessoryView
        }
        if let rulerView = horizontalRulerView {
            rulerView.measurementUnits = .points
            rulerView.ruleThickness = SceneScrollView.rulerThickness
            rulerView.reservedThicknessForMarkers = SceneScrollView.reservedThicknessForMarkers
            rulerView.reservedThicknessForAccessoryView = SceneScrollView.reservedThicknessForAccessoryView
        }
        
        reloadSceneRulers()
        reloadSceneBackground()
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            sceneActionEffectView.addSubview(areaDraggingOverlay)
            sceneActionEffectView.addSubview(annotatorDraggingOverlay)
        }
        else {
            areaDraggingOverlay.removeFromSuperview()
            annotatorDraggingOverlay.removeFromSuperview()
        }
    }
    
    fileprivate func reloadSceneRulers() { rulersVisible = drawRulersInScene }
    fileprivate func reloadSceneBackground() {
        if drawSceneBackground {
            backgroundColor = NSColor.init(patternImage: NSImage(named: "JSTBackgroundPattern")!)
        }
        else {
            backgroundColor = NSColor.controlBackgroundColor
        }
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
    
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    override func pressureChange(with event: NSEvent) {
        if event.stage > sceneState.stage {
            sceneState.stage = event.stage
        }
    }
    
    override func mouseEntered(with event: NSEvent) { trackMovingOrDragging(with: event) }
    override func mouseMoved(with event: NSEvent) { trackMovingOrDragging(with: event) }
    override func mouseExited(with event: NSEvent) { trackMovingOrDragging(with: event) }
    
    override func mouseDown(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.mouseDown) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseDown(with: event) })
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            sceneState.type = .leftGeneric
            sceneState.stage = 0
            sceneState.beginLocation = currentLocation
            sceneState.manipulatingOverlay = nil
            trackMovingOrDragging(with: event)
        }
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.mouseDown) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseDown(with: event) })
    }
    
    override func rightMouseDown(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDown) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseDown(with: event) })
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            sceneState.type = .rightGeneric
            sceneState.stage = 0
            sceneState.beginLocation = currentLocation
            sceneState.manipulatingOverlay = nil
            trackMovingOrDragging(with: event)
        }
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDown) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseDown(with: event) })
    }
    
    override func mouseUp(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.mouseUp) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseUp(with: event) })
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            trackMovingOrDragging(with: event)
            if sceneState.isDragging {
                trackDidEndDragging(with: event)
            }
        }
        
        sceneState.reset()
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.mouseUp) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseUp(with: event) })
    }
    
    override func rightMouseUp(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseUp) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseUp(with: event) })
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            trackMovingOrDragging(with: event)
            if sceneState.isDragging {
                trackDidEndDragging(with: event)
            }
        }
        
        sceneState.reset()
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseUp) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseUp(with: event) })
    }
    
    override func mouseDragged(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.mouseDragged) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseDragged(with: event) })
        
        guard !sceneState.beginLocation.isNull else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(sceneState.beginLocation) >= minimumDraggingDistance {
            let type = SceneManipulatingType.leftDraggingType(for: sceneTool)
            if type.level > sceneState.type.level {
                if type == .areaDragging {
                    if shouldBeginAreaDragging(for: event) {
                        sceneState.type = .areaDragging
                    } else {
                        sceneState.type = .forbidden
                    }
                }
                else if type == .annotatorDragging {
                    if let overlay = overlayForAnnotatorDragging(for: event) as? ColorAnnotatorOverlay,
                        let capturedImage = overlay.capturedImage
                    {
                        sceneState.manipulatingOverlay = overlay
                        sceneState.type = .annotatorDragging
                        annotatorDraggingOverlay.setImage(capturedImage, size: capturedImage.size)
                    } else {
                        sceneState.type = .forbidden
                    }
                }
                else {
                    sceneState.type = type
                }
            }
        }
        
        if sceneState.isDragging {
            if sceneState.type == .sceneDragging {
                let origin = contentView.bounds.origin
                let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
                contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
            else if sceneState.type == .areaDragging {
                let rect = CGRect(point1: sceneState.beginLocation, point2: currentLocation).inset(by: areaDraggingOverlay.outerInsets).intersection(bounds)
                areaDraggingOverlay.frame = convert(rect, to: sceneActionEffectView)
            }
            else if sceneState.type == .annotatorDragging {
                let origin = currentLocation.offsetBy(-annotatorDraggingOverlay.bounds.center)
                annotatorDraggingOverlay.setFrameOrigin(convert(origin, to: sceneActionEffectView))
            }
        }
        trackMovingOrDragging(with: event)
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.mouseDragged) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseDragged(with: event) })
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDragged) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseDragged(with: event) })
        
        guard !sceneState.beginLocation.isNull else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(sceneState.beginLocation) >= minimumDraggingDistance {
            let type = SceneManipulatingType.rightDraggingType(for: sceneTool)
            if sceneState.type != type {
                sceneState.type = type
            }
        }
        trackMovingOrDragging(with: event)
        
        updateDraggingAppearance(for: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDragged) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseDragged(with: event) })
    }
    
    override func scrollWheel(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.scrollWheel) && $0.order.contains(.before) })
            .forEach({ $0.target?.scrollWheel(with: event) })
        
        super.scrollWheel(with: event)
        
        sceneEventObservers
            .filter({ $0.types.contains(.scrollWheel) && $0.order.contains(.after) })
            .forEach({ $0.target?.scrollWheel(with: event) })
    }
    
    override func magnify(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.magnify) && $0.order.contains(.before) })
            .forEach({ $0.target?.magnify(with: event) })
        
        super.magnify(with: event)
        
        sceneEventObservers
            .filter({ $0.types.contains(.magnify) && $0.order.contains(.after) })
            .forEach({ $0.target?.magnify(with: event) })
    }
    
    override func smartMagnify(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.smartMagnify) && $0.order.contains(.before) })
            .forEach({ $0.target?.smartMagnify(with: event) })
        
        super.smartMagnify(with: event)
        
        sceneEventObservers
            .filter({ $0.types.contains(.smartMagnify) && $0.order.contains(.after) })
            .forEach({ $0.target?.smartMagnify(with: event) })
    }
    
    override func reflectScrolledClipView(_ cView: NSClipView) {
        trackingDelegate?.trackSceneBoundsChanged(self, to: cView.bounds.intersection(wrapper.bounds), of: max(min(magnification, maxMagnification), minMagnification))
        super.reflectScrolledClipView(cView)
    }
    
    fileprivate func shouldBeginAreaDragging(for event: NSEvent) -> Bool {
        let shiftPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        if enableForceTouch {
            return shiftPressed || sceneState.stage >= requiredEventStageFor(sceneTool)
        } else {
            return shiftPressed
        }
    }
    
    fileprivate func overlayForAnnotatorDragging(for event: NSEvent) -> Overlay? {
        return sceneStateDataSource?.overlayAtBeginLocation
    }
    
    fileprivate func trackMovingOrDragging(with event: NSEvent) {
        if sceneState.type != .sceneDragging {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if wrapper.bounds.contains(loc) {
                let currentCoordinate = PixelCoordinate(loc)
                if currentCoordinate != trackingCoordinate {
                    trackingCoordinate = currentCoordinate
                    trackingDelegate?.trackColorChanged(self, at: currentCoordinate)
                }
            }
        }
        if sceneState.type == .areaDragging {
            let draggingArea = areaDraggingOverlayPixelRect
            if !draggingArea.isEmpty {
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func trackDidEndDragging(with event: NSEvent) {
        if sceneState.type == .areaDragging {
            let draggingArea = areaDraggingOverlayPixelRect
            if draggingArea.size > PixelSize(width: 1, height: 1) {
                if sceneTool == .magicCursor {
                    trackingDelegate?.trackCursorDragged(self, to: draggingArea)
                }
                else if sceneTool == .magnifyingGlass {
                    trackingDelegate?.trackMagnifyToolDragged(self, to: draggingArea)
                }
            }
        }
        else if sceneState.type == .annotatorDragging {
            let draggingCoordinate = annotatorDraggingOverlayPixelCoordinate
            if !draggingCoordinate.isNull {
                if sceneTool == .selectionArrow {
                    trackingDelegate?.trackCursorDragged(self, to: draggingCoordinate)
                }
            }
        }
    }
    
    fileprivate func updateDraggingAppearance(for event: NSEvent) {
        if sceneState.type == .areaDragging {
            if areaDraggingOverlay.isHidden {
                areaDraggingOverlay.bringToFront()
                areaDraggingOverlay.isHidden = false
            }
        }
        else if !areaDraggingOverlay.isHidden {
            areaDraggingOverlay.isHidden = true
            areaDraggingOverlay.frame = CGRect.zero
        }
        
        if sceneState.type == .annotatorDragging {
            if annotatorDraggingOverlay.isHidden {
                annotatorDraggingOverlay.bringToFront()
                annotatorDraggingOverlay.isHidden = false
            }
        }
        else if !annotatorDraggingOverlay.isHidden {
            annotatorDraggingOverlay.isHidden = true
            annotatorDraggingOverlay.reset()
        }
    }
    
}
