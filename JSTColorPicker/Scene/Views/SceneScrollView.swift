//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import CoreImage

class SceneScrollView: NSScrollView {
    
    
    // MARK: - Wrapper Shortcuts
    
    private var wrapper: SceneImageWrapper { return documentView as! SceneImageWrapper }
    public var wrapperBounds: CGRect { wrapper.bounds }
    public var wrapperVisibleRect: CGRect { wrapper.visibleRect }
    public var wrapperMangnification: CGFloat { magnification }
    public var wrapperRestrictedRect: CGRect { wrapperVisibleRect.intersection(wrapperBounds) }
    public var wrapperRestrictedMagnification: CGFloat { max(min(wrapperMangnification, maxMagnification), minMagnification) }
    
    
    // MARK: - Rulers Shortcuts
    
    private static let rulerThickness: CGFloat = 16.0
    private static let reservedThicknessForMarkers: CGFloat = 15.0
    private static let reservedThicknessForAccessoryView: CGFloat = 0.0
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
    
    
    // MARK: - Location Shortcuts
    
    public var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRectExcludingRulers.contains(loc) {
                return true
            }
        }
        return false
    }
    
    
    // MARK: - Scene Shortcuts
    
    public var sceneEventObservers = Set<SceneEventObserver>()
    public weak var sceneToolSource: SceneToolSource!
    private var sceneTool: SceneTool { sceneToolSource.sceneTool }
    public weak var sceneStateSource: SceneStateSource!
    private var sceneState: SceneState { sceneStateSource.sceneState }
    public weak var sceneActionEffectViewSource: SceneEffectViewSource!
    private var sceneActionEffectView: SceneEffectView { sceneActionEffectViewSource.sourceSceneEffectView }
    
    
    // MARK: - Dragging Shortcuts
    
    private lazy var areaDraggingOverlay: DraggingOverlay = {
        let view = DraggingOverlay()
        view.isHidden = true
        return view
    }()
    private var areaDraggingOverlayRect: PixelRect {
        let rect = sceneActionEffectView.convert(areaDraggingOverlay.frame, to: wrapper).intersection(wrapperBounds)
        guard !rect.isEmpty else { return .null }
        return PixelRect(CGRect(origin: rect.origin, size: CGSize(width: ceil(ceil(rect.maxX) - floor(rect.minX)), height: ceil(ceil(rect.maxY) - floor(rect.minY)))))
    }
    
    private lazy var colorDraggingOverlay: ImageOverlay = {
        let view = ImageOverlay()
        view.alphaValue = 0.9
        view.isHidden = true
        return view
    }()
    private var colorDraggingOverlayCoordinate: PixelCoordinate {
        let point = sceneActionEffectView.convert(colorDraggingOverlay.frame.center, to: wrapper)
        guard wrapperBounds.contains(point) else { return .null }
        return PixelCoordinate(point)
    }
    
    
    // MARK: - Interface Builder
    
    override var isFlipped: Bool { true }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wantsLayer = false
        
        SceneScrollView.rulerViewClass = RulerView.self
        contentInsets = NSEdgeInsetsZero
        drawsBackground = true
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic
        scrollerStyle = .overlay
        scrollerKnobStyle = .default
        autohidesScrollers = false
        borderType = .noBorder
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
    
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        trackingDelegate.sceneWillStartLiveResize(self)
    }
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        trackingDelegate.sceneDidEndLiveResize(self)
    }
    
    public var drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground] {
        didSet { reloadSceneBackground() }
    }
    public var drawRulersInScene: Bool = UserDefaults.standard[.drawRulersInScene] {
        didSet { reloadSceneRulers() }
    }
    
    private func reloadSceneRulers() { rulersVisible = drawRulersInScene }
    private func reloadSceneBackground() {
        if drawSceneBackground {
            backgroundColor = NSColor.init(patternImage: SceneScrollView.checkerboardImage)
        }
        else {
            backgroundColor = NSColor.controlBackgroundColor
        }
    }
    
    
    // MARK: - Events
    
    public var enableForceTouch: Bool = false
    private var minimumDraggingDistance: CGFloat { enableForceTouch ? 6.0 : 3.0 }
    private func requiredEventStageFor(_ tool: SceneTool) -> Int { enableForceTouch ? 1 : 0 }
    
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
            sceneState.manipulatingType = .leftGeneric
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
            sceneState.manipulatingType = .rightGeneric
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
            let type = SceneState.ManipulatingType.leftDraggingType(for: sceneTool)
            if type.level > sceneState.manipulatingType.level {
                if type == .sceneDragging {
                    sceneState.manipulatingType = shouldBeginSceneDragging(for: event) ? .sceneDragging : .forbidden
                }
                else if type == .areaDragging {
                    sceneState.manipulatingType = shouldBeginAreaDragging(for: event) ? .areaDragging : .forbidden
                }
                else if type == .annotatorDragging {
                    if shouldBeginAnnotatorDragging(for: event),
                        let overlay = beginAnnotatorDragging(for: event) {
                        var shouldBeginEditing = false
                        if let colorAnnotatorOverlay = overlay as? ColorAnnotatorOverlay,
                            let capturedImage = colorAnnotatorOverlay.capturedImage
                        {
                            colorDraggingOverlay.setImage(capturedImage, size: capturedImage.size)
                            shouldBeginEditing = true
                        }
                        else if let areaAnnotatorOverlay = overlay as? AreaAnnotatorOverlay,
                            areaAnnotatorOverlay.editableEdge != .none
                        {
                            areaDraggingOverlay.animationState = areaAnnotatorOverlay.animationState
                            shouldBeginEditing = true
                        }
                        if shouldBeginEditing {
                            if overlay.hidesDuringEditing { overlay.isHidden = true }
                            sceneState.manipulatingOverlay = overlay
                            sceneState.manipulatingType = .annotatorDragging
                        }
                        else { sceneState.manipulatingType = .forbidden }
                    }
                    else { sceneState.manipulatingType = .forbidden }
                }
                else { sceneState.manipulatingType = type }
                trackWillBeginDragging(with: event)
            }
        }
        
        if sceneState.isDragging {
            if sceneState.manipulatingType == .sceneDragging {
                let origin = contentView.bounds.origin
                let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
                contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
            else if sceneState.manipulatingType == .areaDragging {
                let rect = CGRect(point1: sceneState.beginLocation, point2: currentLocation).inset(by: areaDraggingOverlay.outerInsets)
                areaDraggingOverlay.frame = convert(rect, to: sceneActionEffectView).intersection(sceneActionEffectView.bounds)
            }
            else if sceneState.manipulatingType == .annotatorDragging {
                let locInAction = convert(currentLocation, to: sceneActionEffectView)
                if sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
                    let origin = locInAction.offsetBy(-colorDraggingOverlay.bounds.center)
                    colorDraggingOverlay.setFrameOrigin(origin)
                    let beginLocInWrapper = convert(sceneState.beginLocation, to: wrapper)
                    let locInWrapper = convert(currentLocation, to: wrapper)
                    areaDraggingOverlay.contextRect = PixelRect(
                        x: Int(beginLocInWrapper.x),
                        y: Int(beginLocInWrapper.y),
                        width: Int(locInWrapper.x) - Int(beginLocInWrapper.x),
                        height: Int(locInWrapper.y) - Int(beginLocInWrapper.y)
                    )
                }
                else if let areaAnnotatorOverlay = sceneState.manipulatingOverlay as? AreaAnnotatorOverlay {
                    let edge = areaAnnotatorOverlay.editableEdge
                    let annotatorFrame =
                        areaAnnotatorOverlay.frame
                            .inset(by: areaAnnotatorOverlay.innerInsets)
                    let annotatorPixelRect = areaAnnotatorOverlay.rect
                    let locInWrapper = convert(currentLocation, to: wrapper)
                    if edge.isCorner {
                        var fixedOpposite: CGPoint?, fixedOppositeCoord: PixelCoordinate?
                        switch edge {
                        case .topLeft:
                            fixedOpposite = CGPoint(x: annotatorFrame.maxX, y: annotatorFrame.maxY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.maxX, y: annotatorPixelRect.maxY)
                        case .topRight:
                            fixedOpposite = CGPoint(x: annotatorFrame.minX, y: annotatorFrame.maxY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.minX, y: annotatorPixelRect.maxY)
                        case .bottomLeft:
                            fixedOpposite = CGPoint(x: annotatorFrame.maxX, y: annotatorFrame.minY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.maxX, y: annotatorPixelRect.minY)
                        case .bottomRight:
                            fixedOpposite = CGPoint(x: annotatorFrame.minX, y: annotatorFrame.minY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.minX, y: annotatorPixelRect.minY)
                        default: break
                        }
                        if let fixedOpposite = fixedOpposite,
                            let fixedOppositeCoord = fixedOppositeCoord
                        {
                            let newFrame = CGRect(point1: fixedOpposite, point2: locInAction)
                            areaDraggingOverlay.frame =
                                newFrame.inset(by: areaDraggingOverlay.outerInsets)
                            let newPixelRect = PixelRect(
                                coordinate1: fixedOppositeCoord,
                                coordinate2: PixelCoordinate(
                                    x: Int(round(locInWrapper.x)),
                                    y: Int(round(locInWrapper.y))
                                )
                            )
                            areaDraggingOverlay.contextRect = newPixelRect.intersection(wrapper.pixelBounds)
                        }
                    }
                    else if edge.isMiddle {
                        var locAligned = locInAction
                        var locAlignedCoord = PixelCoordinate(x: Int(round(locInWrapper.x)), y: Int(round(locInWrapper.y)))
                        var fixedOpposite: CGPoint?
                        var fixedOppositeCoord: PixelCoordinate?
                        switch edge {
                        case .middleLeft:
                            locAligned.y = annotatorFrame.minY
                            locAlignedCoord.y = annotatorPixelRect.minY
                            fixedOpposite = CGPoint(x: annotatorFrame.maxX, y: annotatorFrame.maxY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.maxX, y: annotatorPixelRect.maxY)
                        case .topMiddle:
                            locAligned.x = annotatorFrame.maxX
                            locAlignedCoord.x = annotatorPixelRect.maxX
                            fixedOpposite = CGPoint(x: annotatorFrame.minX, y: annotatorFrame.maxY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.minX, y: annotatorPixelRect.maxY)
                        case .bottomMiddle:
                            locAligned.x = annotatorFrame.minX
                            locAlignedCoord.x = annotatorPixelRect.minX
                            fixedOpposite = CGPoint(x: annotatorFrame.maxX, y: annotatorFrame.minY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.maxX, y: annotatorPixelRect.minY)
                        case .middleRight:
                            locAligned.y = annotatorFrame.maxY
                            locAlignedCoord.y = annotatorPixelRect.maxY
                            fixedOpposite = CGPoint(x: annotatorFrame.minX, y: annotatorFrame.minY)
                            fixedOppositeCoord = PixelCoordinate(x: annotatorPixelRect.minX, y: annotatorPixelRect.minY)
                        default: break
                        }
                        if let fixedOpposite = fixedOpposite, let fixedOppositeCoord = fixedOppositeCoord {
                            let newFrame = CGRect(point1: fixedOpposite, point2: locAligned)
                            areaDraggingOverlay.frame =
                                newFrame.inset(by: areaDraggingOverlay.outerInsets)
                            let newPixelRect = PixelRect(
                                coordinate1: fixedOppositeCoord,
                                coordinate2: locAlignedCoord
                            )
                            areaDraggingOverlay.contextRect = newPixelRect.intersection(wrapper.pixelBounds)
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
            let type = SceneState.ManipulatingType.rightDraggingType(for: sceneTool)
            if sceneState.manipulatingType != type {
                sceneState.manipulatingType = type
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
        let currentLocation = wrapper.convert(event.locationInWindow, from: nil)
        guard wrapperBounds.contains(currentLocation) else { return }
        
        sceneEventObservers
            .filter({ $0.types.contains(.magnify) && $0.order.contains(.before) })
            .forEach({ $0.target?.magnify(with: event) })
        
        super.magnify(with: event)
        
        sceneEventObservers
            .filter({ $0.types.contains(.magnify) && $0.order.contains(.after) })
            .forEach({ $0.target?.magnify(with: event) })
    }
    
    override func smartMagnify(with event: NSEvent) {
        let currentLocation = wrapper.convert(event.locationInWindow, from: nil)
        guard wrapperBounds.contains(currentLocation) else { return }
        
        sceneEventObservers
            .filter({ $0.types.contains(.smartMagnify) && $0.order.contains(.before) })
            .forEach({ $0.target?.smartMagnify(with: event) })
        
        super.smartMagnify(with: event)
        
        sceneEventObservers
            .filter({ $0.types.contains(.smartMagnify) && $0.order.contains(.after) })
            .forEach({ $0.target?.smartMagnify(with: event) })
    }
    
    override func reflectScrolledClipView(_ clipView: NSClipView) {
        guard let trackingDelegate = trackingDelegate else { return }
        let rect = wrapperVisibleRect
        if rect.isEmpty {
            // FIX: weird behavior in AppKit
            guard Thread.callStackSymbols.first(where: { $0.contains("magnifyWithEvent:") || $0.contains("runAnimationGroup:") }) == nil else { return }
        }
        trackingDelegate.sceneVisibleRectDidChange(self, to: rect, of: magnification)
        super.reflectScrolledClipView(clipView)
    }
    
    
    // MARK: - Event Tracking
    
    public weak var trackingDelegate: SceneActionTracking!
    private var trackingArea: NSTrackingArea?
    private var trackingCoordinate = PixelCoordinate.null
    
    private func createTrackingArea() {
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
    
    private func shouldBeginSceneDragging(for event: NSEvent) -> Bool {
        return sceneState.stage >= requiredEventStageFor(sceneTool)
    }
    
    private func shouldBeginAreaDragging(for event: NSEvent) -> Bool {
        let shiftPressed = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.shift)
        if enableForceTouch {
            return shiftPressed || sceneState.stage >= requiredEventStageFor(sceneTool)
        } else {
            return shiftPressed
        }
    }
    
    private func shouldBeginAnnotatorDragging(for event: NSEvent) -> Bool {
        return sceneState.stage >= requiredEventStageFor(sceneTool)
    }
    
    private func beginAnnotatorDragging(for event: NSEvent) -> EditableOverlay? {
        return sceneStateSource.beginEditing()
    }
    
    private func trackMovingOrDragging(with event: NSEvent) {
        if sceneState.manipulatingType != .sceneDragging {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if wrapperBounds.contains(loc) {
                let currentCoordinate = PixelCoordinate(loc)
                if currentCoordinate != trackingCoordinate {
                    trackingCoordinate = currentCoordinate
                    trackingDelegate.sceneRawColorDidChange(self, at: currentCoordinate)
                }
            }
        }
        if sceneState.manipulatingType == .areaDragging {
            let draggingRect = areaDraggingOverlayRect
            if !draggingRect.isEmpty {
                trackingDelegate.sceneRawAreaDidChange(self, to: draggingRect)
            }
        }
        else if sceneState.manipulatingType == .annotatorDragging {
            if let draggingRect = areaDraggingOverlay.contextRect, !draggingRect.isEmpty {
                trackingDelegate.sceneRawAreaDidChange(self, to: draggingRect)
            }
        }
    }
    
    private func trackWillBeginDragging(with event: NSEvent) {
        if sceneState.manipulatingType == .sceneDragging {
            trackingDelegate.sceneMovingHandActionWillBegin(self)
        }
    }
    
    private func trackDidEndDragging(with event: NSEvent) {
        if sceneState.manipulatingType == .sceneDragging {
            trackingDelegate.sceneMovingHandActionDidEnd(self)
        }
        else if sceneState.manipulatingType == .areaDragging {
            let draggingRect = areaDraggingOverlayRect
            if draggingRect.hasStandardized && draggingRect.size > PixelSize(width: 1, height: 1)
            {
                if sceneTool == .magicCursor {
                    trackingDelegate.sceneMagicCursorActionDidEnd(self, to: draggingRect)
                }
                else if sceneTool == .magnifyingGlass {
                    trackingDelegate.sceneMagnifyingGlassActionDidEnd(self, to: draggingRect)
                }
            }
        }
        else if sceneState.manipulatingType == .annotatorDragging {
            if sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
                let draggingCoordinate = colorDraggingOverlayCoordinate
                if !draggingCoordinate.isNull {
                    if sceneTool == .selectionArrow {
                        trackingDelegate.sceneMagicCursorActionDidEnd(self, to: draggingCoordinate)
                    }
                }
            }
            else if sceneState.manipulatingOverlay is AreaAnnotatorOverlay {
                if let draggingRect = areaDraggingOverlay.contextRect,
                    draggingRect.hasStandardized && draggingRect.size > PixelSize(width: 1, height: 1)
                {
                    if sceneTool == .selectionArrow {
                        trackingDelegate.sceneMagicCursorActionDidEnd(self, to: draggingRect)
                    }
                }
            }
        }
    }
    
    private func updateDraggingAppearance(for event: NSEvent) {
        if sceneState.manipulatingType == .annotatorDragging && sceneState.manipulatingOverlay is ColorAnnotatorOverlay {
            if colorDraggingOverlay.isHidden {
                colorDraggingOverlay.bringToFront()
                colorDraggingOverlay.isHidden = false
            }
        }
        else if !colorDraggingOverlay.isHidden {
            colorDraggingOverlay.isHidden = true
            colorDraggingOverlay.reset()
        }
        if sceneState.manipulatingType == .areaDragging || (sceneState.manipulatingType == .annotatorDragging && sceneState.manipulatingOverlay is AreaAnnotatorOverlay) {
            if areaDraggingOverlay.isHidden {
                areaDraggingOverlay.bringToFront()
                areaDraggingOverlay.isHidden = false
            }
        }
        else if !areaDraggingOverlay.isHidden {
            areaDraggingOverlay.isHidden = true
            areaDraggingOverlay.frame = CGRect.zero
            areaDraggingOverlay.animationState = OverlayAnimationState()
        }
    }
    
}

extension SceneScrollView {
    private static var checkerboardImage: NSImage = {
        let filter = CIFilter(name: "CICheckerboardGenerator")!
        
        let ciCount: Int    = 8
        let ciSize : CGSize = CGSize(width: 80.0, height: 80.0)
        let aSize  : CGSize = CGSize(width: ciSize.width * CGFloat(ciCount), height: ciSize.height * CGFloat(ciCount))
        
        let ciWidth    = NSNumber(value: Double(ciSize.width))
        let ciCenter   = CIVector(cgPoint: .zero)
        let darkColor  = CIColor.init(cgColor: CGColor.init(gray: 0xCC / 0xFF, alpha: 0.6))
        let lightColor = CIColor.clear
        let sharpness  = NSNumber(value: 1.0)
        
        filter.setDefaults()
        filter.setValue(ciWidth, forKey: "inputWidth")
        filter.setValue(ciCenter, forKey: "inputCenter")
        filter.setValue(darkColor, forKey: "inputColor0")
        filter.setValue(lightColor, forKey: "inputColor1")
        filter.setValue(sharpness, forKey: "inputSharpness")
        
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(filter.outputImage!, from: CGRect(origin: .zero, size: aSize))
        
        return NSImage(cgImage: cgImage!, size: ciSize)
    }()
}

