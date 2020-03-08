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
    fileprivate var areaDraggingOverlayRect: PixelRect {
        let rect = sceneActionEffectView.convert(areaDraggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
        guard !rect.isEmpty else { return .null }
        return PixelRect(CGRect(origin: rect.origin, size: CGSize(width: ceil(ceil(rect.maxX) - floor(rect.minX)), height: ceil(ceil(rect.maxY) - floor(rect.minY)))))
    }
    fileprivate var annotatorDraggingOverlayRect: PixelRect {
        let rect = sceneActionEffectView.convert(areaDraggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
        guard !rect.isEmpty else { return .null }
        return PixelRect(CGRect(point1: CGPoint(x: round(rect.minX), y: round(rect.minY)), point2: CGPoint(x: round(rect.maxX), y: round(rect.maxY))))
    }
    
    fileprivate lazy var colorDraggingOverlay: ImageOverlay = {
        let view = ImageOverlay()
        view.alphaValue = 0.9
        view.isHidden = true
        return view
    }()
    fileprivate var colorDraggingOverlayCoordinate: PixelCoordinate {
        let point = sceneActionEffectView.convert(colorDraggingOverlay.frame.center, to: wrapper)
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
            sceneActionEffectView.addSubview(colorDraggingOverlay)
        }
        else {
            areaDraggingOverlay.removeFromSuperview()
            colorDraggingOverlay.removeFromSuperview()
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
        
        if let overlay = sceneState.manipulatingOverlay, overlay.hidesDuringEditing { overlay.isHidden = false }
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
                    sceneState.type = shouldBeginAreaDragging(for: event) ? .areaDragging : .forbidden
                }
                else if type == .annotatorDragging {
                    if let overlay = editingAnnotatorOverlayForAnnotatorDragging(for: event) {
                        var shouldBeginEditing = false
                        if let colorAnnotatorOverlay = overlay as? ColorAnnotatorOverlay,
                            let capturedImage = colorAnnotatorOverlay.capturedImage
                        {
                            colorDraggingOverlay.setImage(capturedImage, size: capturedImage.size)
                            shouldBeginEditing = true
                        }
                        else if let areaAnnotatorOverlay = overlay as? AreaAnnotatorOverlay,
                            areaAnnotatorOverlay.editingEdge != .none
                        {
                            areaDraggingOverlay.lineDashCount = areaAnnotatorOverlay.lineDashCount
                            shouldBeginEditing = true
                        }
                        if shouldBeginEditing {
                            if overlay.hidesDuringEditing { overlay.isHidden = true }
                            sceneState.manipulatingOverlay = overlay
                            sceneState.type = .annotatorDragging
                        }
                        else { sceneState.type = .forbidden }
                    }
                    else { sceneState.type = .forbidden }
                }
                else { sceneState.type = type }
            }
        }
        
        if sceneState.isDragging {
            if sceneState.type == .sceneDragging {
                let origin = contentView.bounds.origin
                let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
                contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
            else if sceneState.type == .areaDragging {
                let rect = CGRect(point1: sceneState.beginLocation, point2: currentLocation).inset(by: areaDraggingOverlay.outerInsets)
                areaDraggingOverlay.frame = convert(rect, to: sceneActionEffectView).intersection(sceneActionEffectView.bounds)
            }
            else if sceneState.type == .annotatorDragging {
                let locInAction = convert(currentLocation, to: sceneActionEffectView)
                if sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
                    let origin = locInAction.offsetBy(-colorDraggingOverlay.bounds.center)
                    colorDraggingOverlay.setFrameOrigin(origin)
                }
                else if let areaAnnotatorOverlay = sceneState.manipulatingOverlay as? AreaAnnotatorOverlay {
                    let edge = areaAnnotatorOverlay.editingEdge
                    let annotatorRect =
                        areaAnnotatorOverlay.frame
                            .inset(by: areaAnnotatorOverlay.innerInsets)
                    if edge.isCorner {
                        var fixedOpposite: CGPoint?
                        switch edge {
                        case .topLeft:
                            fixedOpposite = CGPoint(x: annotatorRect.maxX, y: annotatorRect.maxY)
                        case .topRight:
                            fixedOpposite = CGPoint(x: annotatorRect.minX, y: annotatorRect.maxY)
                        case .bottomLeft:
                            fixedOpposite = CGPoint(x: annotatorRect.maxX, y: annotatorRect.minY)
                        case .bottomRight:
                            fixedOpposite = CGPoint(x: annotatorRect.minX, y: annotatorRect.minY)
                        default: break
                        }
                        if let fixedOpposite = fixedOpposite {
                            let rect = CGRect(point1: fixedOpposite, point2: locInAction)
                            areaDraggingOverlay.frame =
                                rect.inset(by: areaDraggingOverlay.outerInsets)
                                    // .intersection(sceneActionEffectView.bounds)
                        }
                    }
                    else if edge.isMiddle {
                        var fixedLoc = locInAction
                        var fixedOpposite: CGPoint?
                        switch edge {
                        case .middleLeft:
                            fixedLoc.y = annotatorRect.minY
                            fixedOpposite = CGPoint(x: annotatorRect.maxX, y: annotatorRect.maxY)
                        case .topMiddle:
                            fixedLoc.x = annotatorRect.maxX
                            fixedOpposite = CGPoint(x: annotatorRect.minX, y: annotatorRect.maxY)
                        case .bottomMiddle:
                            fixedLoc.x = annotatorRect.minX
                            fixedOpposite = CGPoint(x: annotatorRect.maxX, y: annotatorRect.minY)
                        case .middleRight:
                            fixedLoc.y = annotatorRect.maxY
                            fixedOpposite = CGPoint(x: annotatorRect.minX, y: annotatorRect.minY)
                        default: break
                        }
                        if let fixedOpposite = fixedOpposite {
                            let rect = CGRect(point1: fixedOpposite, point2: fixedLoc)
                            areaDraggingOverlay.frame =
                                rect.inset(by: areaDraggingOverlay.outerInsets)
                                    // .intersection(sceneActionEffectView.bounds)
                        }
                    }
                    else {
                        areaDraggingOverlay.frame =
                            areaAnnotatorOverlay.frame
                                .inset(by: areaAnnotatorOverlay.innerInsets)
                                .inset(by: areaDraggingOverlay.outerInsets)
                    }
                }
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
    
    fileprivate func editingAnnotatorOverlayForAnnotatorDragging(for event: NSEvent) -> EditableOverlay? {
        return sceneStateDataSource?.editingAnnotatorOverlayAtBeginLocation
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
            let draggingArea = areaDraggingOverlayRect
            if !draggingArea.isEmpty {
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
        else if sceneState.type == .annotatorDragging {
            let draggingArea = annotatorDraggingOverlayRect
            if !draggingArea.isEmpty {
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func trackDidEndDragging(with event: NSEvent) {
        if sceneState.type == .areaDragging {
            let draggingArea = areaDraggingOverlayRect
            if draggingArea.size > PixelSize(width: 1, height: 1) {
                if sceneTool == .magicCursor {
                    trackingDelegate?.trackMagicCursorDragged(self, to: draggingArea)
                }
                else if sceneTool == .magnifyingGlass {
                    trackingDelegate?.trackMagnifyingGlassDragged(self, to: draggingArea)
                }
            }
        }
        else if sceneState.type == .annotatorDragging {
            if sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
                let draggingCoordinate = colorDraggingOverlayCoordinate
                if !draggingCoordinate.isNull {
                    if sceneTool == .selectionArrow {
                        trackingDelegate?.trackMagicCursorDragged(self, to: draggingCoordinate)
                    }
                }
            }
            else if sceneState.manipulatingOverlay is AreaAnnotatorOverlay {
                let draggingArea = annotatorDraggingOverlayRect
                if draggingArea.size > PixelSize(width: 1, height: 1) {
                    if sceneTool == .selectionArrow {
                        trackingDelegate?.trackMagicCursorDragged(self, to: draggingArea)
                    }
                }
            }
        }
    }
    
    fileprivate func updateDraggingAppearance(for event: NSEvent) {
        if sceneState.type == .annotatorDragging && sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
            if colorDraggingOverlay.isHidden {
                colorDraggingOverlay.bringToFront()
                colorDraggingOverlay.isHidden = false
            }
        }
        else if !colorDraggingOverlay.isHidden {
            colorDraggingOverlay.isHidden = true
            colorDraggingOverlay.reset()
        }
        if sceneState.type == .areaDragging || (sceneState.type == .annotatorDragging && sceneState.manipulatingOverlay is AreaAnnotatorOverlay) {
            if areaDraggingOverlay.isHidden {
                areaDraggingOverlay.bringToFront()
                areaDraggingOverlay.isHidden = false
            }
        }
        else if !areaDraggingOverlay.isHidden {
            areaDraggingOverlay.isHidden = true
            areaDraggingOverlay.frame = CGRect.zero
            areaDraggingOverlay.lineDashCount = 0
        }
    }
    
}
