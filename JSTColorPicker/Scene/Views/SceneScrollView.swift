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
    
    // MARK: - Internal Notifications
    static let willStartSmartMagnifyNotification = NSNotification.Name("SceneScrollView.willStartSmartMagnifyNotification")
    static let didEndSmartMagnifyNotification = NSNotification.Name("SceneScrollView.didEndSmartMagnifyNotification")
    
    
    // MARK: - Wrapper Shortcuts
    
    private var wrapper: SceneImageWrapper { return documentView as! SceneImageWrapper }
    var wrapperBounds: CGRect { wrapper.bounds }
    var wrapperVisibleRect: CGRect { wrapper.visibleRect }
    var wrapperMangnification: CGFloat { magnification }
    var wrapperRestrictedRect: CGRect { wrapperVisibleRect.intersection(wrapperBounds) }
    var wrapperRestrictedMagnification: CGFloat { max(min(wrapperMangnification, maxMagnification), minMagnification) }
    
    
    // MARK: - Rulers Shortcuts
    
    private static let rulerThickness: CGFloat = 16.0
    private static let reservedThicknessForMarkers: CGFloat = 12.0
    private static let reservedThicknessForAccessoryView: CGFloat = 0.0
    var visibleRectExcludingRulers: CGRect {
        let rect = visibleRect
        return CGRect(x: rect.minX + alternateBoundsOrigin.x, y: rect.minY + alternateBoundsOrigin.y, width: rect.width - alternateBoundsOrigin.x, height: rect.height - alternateBoundsOrigin.y)
    }
    
    var alternateBoundsOrigin: CGPoint {
        if drawRulersInScene {
            return CGPoint(x: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView, y: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView)
        }
        return CGPoint.zero
    }
    
    
    // MARK: - Location Shortcuts
    
    var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRectExcludingRulers.contains(loc) {
                return true
            }
        }
        return false
    }
    
    
    // MARK: - Scene Shortcuts
    
    internal var sceneEventObservers = Set<SceneEventObserver>()
    weak     var sceneToolSource     : SceneToolSource!
    private  var sceneTool           : SceneTool  { sceneToolSource.sceneTool   }
    weak     var sceneStateSource    : SceneStateSource!
    private  var sceneState          : SceneState { sceneStateSource.sceneState }
    weak     var sceneActionEffectViewSource  : SceneEffectViewSource!
    private  var sceneActionEffectView        : SceneEffectView
    { sceneActionEffectViewSource.sourceSceneEffectView }
    
    
    // MARK: - Dragging Shortcuts
    
    private lazy var areaDraggingOverlay: DraggingOverlay = {
        let view = DraggingOverlay()
        view.isHidden = true
        return view
    }()

    private var areaDraggingOverlayRect: PixelRect {
        let overlayFrame = sceneActionEffectView.convert(
            areaDraggingOverlay.frame,
            to: wrapper
        )
        guard !overlayFrame.isEmpty else {
            return .null
        }

        var pRect: PixelRect
        if sceneState.isProportionalScaling {
            let maxWidth = max(
                ceil(ceil(overlayFrame.maxX) - floor(overlayFrame.minX)),
                ceil(ceil(overlayFrame.maxY) - floor(overlayFrame.minY))
            )
            pRect = PixelRect(
                CGRect(
                    origin: overlayFrame.origin,
                    size: CGSize(
                        width: maxWidth,
                        height: maxWidth
                    )
                )
            )
        } else {
            let fixedFrame = overlayFrame.intersection(wrapperBounds)
            guard !fixedFrame.isEmpty else {
                return .null
            }

            pRect = PixelRect(
                CGRect(
                    origin: fixedFrame.origin,
                    size: CGSize(
                        width: ceil(ceil(fixedFrame.maxX) - floor(fixedFrame.minX)),
                        height: ceil(ceil(fixedFrame.maxY) - floor(fixedFrame.minY))
                    )
                )
            )
        }

        return pRect.intersection(wrapper.pixelBounds)
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
        drawsBackground = false
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
    
    var drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground] {
        didSet { reloadSceneBackground() }
    }
    var drawRulersInScene: Bool = UserDefaults.standard[.drawRulersInScene] {
        didSet { reloadSceneRulers() }
    }
    
    private func reloadSceneRulers() { rulersVisible = drawRulersInScene }
    private func reloadSceneBackground() { needsDisplay = true }
    private static let patternBackgroundColor = NSColor.init(patternImage: SceneScrollView.checkerboardImage)
    
    override func draw(_ dirtyRect: NSRect) {
        let yOffset = convert(frame, to: nil).maxY
        NSGraphicsContext.current?.patternPhase = NSMakePoint(0, yOffset)
        
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        
        if drawSceneBackground {
            SceneScrollView.patternBackgroundColor.setFill()
            dirtyRect.fill()
        }
        
        super.draw(dirtyRect)
    }

    
    // MARK: - Events
    
    var isForceTouch             : Bool    { sceneState.stage > 0         }
    var minimumDraggingDistance  : CGFloat { isForceTouch ? 6.0 : 3.0     }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if sceneState.isManipulating {
            return true
        }
        return false
    }
    
    override func cursorUpdate(with event: NSEvent) { }  // do not perform default behavior
    
    override func pressureChange(with event: NSEvent) {
        if event.stage > sceneState.stage {
            sceneState.stage = event.stage
        }
    }
    
    override func mouseEntered(with event: NSEvent) { trackMovingOrDragging(with: event) }
    override func mouseMoved  (with event: NSEvent) { trackMovingOrDragging(with: event) }
    override func mouseExited (with event: NSEvent) { trackMovingOrDragging(with: event) }
    
    private func manipulatingOptions(at side: SceneState.ManipulatingSide, with event: NSEvent) -> SceneState.ManipulatingOptions {
        var opts: SceneState.ManipulatingOptions = []
        let masks = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if side == .left {
            if masks.contains(.shift) {
                opts.formUnion(.proportionalScaling)
            }
            if masks.contains(.option) {
                opts.formUnion(.centeredScaling)
            }
        }
        return opts
    }
    
    private func internalMouseDown(at side: SceneState.ManipulatingSide, withEvent event: NSEvent) {
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            sceneState.manipulatingSide = side
            switch side {
            case .none:
                sceneState.manipulatingType = .none
            case .left:
                sceneState.manipulatingType = .leftGeneric
            case .right:
                sceneState.manipulatingType = .rightGeneric
            }
            sceneState.manipulatingOptions = manipulatingOptions(at: side, with: event)
            sceneState.stage = 0
            sceneState.beginLocation = currentLocation
            sceneState.manipulatingOverlay = nil
            trackMovingOrDragging(with: event)
        }
        
        updateDraggingAppearance(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseDown) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseDown(with: event) })
        internalMouseDown(at: .left, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseDown) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseDown(with: event) })
    }
    
    override func rightMouseDown(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDown) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseDown(with: event) })
        internalMouseDown(at: .right, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDown) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseDown(with: event) })
    }
    
    override func otherMouseDown(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseDown) && $0.order.contains(.before) })
            .forEach({ $0.target?.otherMouseDown(with: event) })
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseDown) && $0.order.contains(.after) })
            .forEach({ $0.target?.otherMouseDown(with: event) })
    }
    
    private func internalMouseUp(at side: SceneState.ManipulatingSide, withEvent event: NSEvent) {
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            trackMovingOrDragging(with: event)
            if sceneState.isDragging {
                trackDidEndDragging(with: event)
            }
        }
        
        if let overlay = sceneState.manipulatingOverlay,
           overlay.hidesDuringEditing
        {
            overlay.isHidden = false
        }
        
        sceneState.reset()
        updateDraggingAppearance(with: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseUp) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseUp(with: event) })
        internalMouseUp(at: .left, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseUp) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseUp(with: event) })
    }
    
    override func rightMouseUp(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseUp) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseUp(with: event) })
        internalMouseUp(at: .right, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseUp) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseUp(with: event) })
    }
    
    override func otherMouseUp(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseUp) && $0.order.contains(.before) })
            .forEach({ $0.target?.otherMouseUp(with: event) })
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseUp) && $0.order.contains(.after) })
            .forEach({ $0.target?.otherMouseUp(with: event) })
    }

    private static func calculatePixelRect(
        beginLocation begin: PixelCoordinate,
        currentLocation end: PixelCoordinate,
        withRatio ratio: CGFloat,
        byProportionalScaling proportional: Bool,
        byCenteredScaling centered: Bool
    ) -> PixelRect
    {
        var targetRect: PixelRect
        if centered && !proportional
        {
            // centered rectangles
            let absOffsetX = abs(end.x - begin.x)
            let absOffsetY = abs(end.y - begin.y)
            targetRect = PixelRect(
                x: end.x >= begin.x ? end.x - absOffsetX * 2 : end.x,
                y: end.y >= begin.y ? end.y - absOffsetY * 2 : end.y,
                width: absOffsetX * 2,
                height: absOffsetY * 2
            )
        }
        else if proportional
        {
            let endOffsetX = end.x - begin.x
            let endOffsetY = end.y - begin.y
            let fixedOffsetY = Int(round(CGFloat(endOffsetX) / ratio))
            targetRect = PixelRect(
                coordinate1: centered ? PixelCoordinate(
                    x: begin.x - endOffsetX,
                    y: begin.y - (endOffsetX * endOffsetY > 0 ? fixedOffsetY : -fixedOffsetY)
                ) : begin,
                coordinate2: PixelCoordinate(
                    x: begin.x + endOffsetX,
                    y: begin.y + (endOffsetX * endOffsetY > 0 ? fixedOffsetY : -fixedOffsetY)
                )
            )
        }
        else {
            // rectangles
            targetRect = PixelRect(
                coordinate1: begin,
                coordinate2: end
            )
        }
        return targetRect
    }

    private static func calculateRect(
        beginLocation begin: CGPoint,
        currentLocation end: CGPoint,
        withRatio ratio: CGFloat,
        byProportionalScaling proportional: Bool,
        byCenteredScaling centered: Bool
    ) -> CGRect
    {
        var targetRect: CGRect
        if centered && !proportional
        {
            // centered rectangles
            let absOffsetX = abs(end.x - begin.x)
            let absOffsetY = abs(end.y - begin.y)
            targetRect = CGRect(
                x: end.x >= begin.x ? end.x - absOffsetX * 2 : end.x,
                y: end.y >= begin.y ? end.y - absOffsetY * 2 : end.y,
                width: absOffsetX * 2,
                height: absOffsetY * 2
            )
        }
        else if proportional
        {
            let endOffsetX = end.x - begin.x
            let endOffsetY = end.y - begin.y
            let fixedOffsetY = endOffsetX / ratio
            targetRect = CGRect(
                point1: centered ? CGPoint(
                    x: begin.x - endOffsetX,
                    y: begin.y - (endOffsetX * endOffsetY > 0 ? fixedOffsetY : -fixedOffsetY)
                ) : begin,
                point2: CGPoint(
                    x: begin.x + endOffsetX,
                    y: begin.y + (endOffsetX * endOffsetY > 0 ? fixedOffsetY : -fixedOffsetY)
                )
            )
        }
        else {
            // rectangles
            targetRect = CGRect(
                point1: begin,
                point2: end
            )
        }
        return targetRect
    }
    
    private func internalMouseDragged(at side: SceneState.ManipulatingSide, withEvent event: NSEvent)
    {
        guard !sceneState.beginLocation.isNull else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(sceneState.beginLocation) >= minimumDraggingDistance {
            let type = SceneState.ManipulatingType.draggingType(at: side, for: sceneTool)
            if type.level > sceneState.manipulatingType.level {
                let altType = alternatingDraggingType(
                    type,
                    withEvent: event
                )
                if altType.level > sceneState.manipulatingType.level {
                    if altType == .annotatorDragging {
                        if let overlay = beginAnnotatorDragging(with: event) {
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
                    } else { sceneState.manipulatingType = altType }
                    
                    let options = sceneState.manipulatingOptions
                    sceneState.manipulatingOptions = alternatingDraggingOptions(
                        options,
                        withEvent: event
                    )
                    
                    trackWillBeginDragging(with: event)
                }
            }
        }
        
        if sceneState.isDragging {
            if sceneState.manipulatingType == .sceneDragging {
                let origin = contentView.bounds.origin
                let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
                contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
            else if sceneState.manipulatingType == .areaDragging {
                let targetRect = SceneScrollView.calculateRect(
                    beginLocation: sceneState.beginLocation,
                    currentLocation: currentLocation,
                    withRatio: 1.0,
                    byProportionalScaling: sceneState.isProportionalScaling,
                    byCenteredScaling: sceneState.isCenteredScaling
                )
                let convertedRect = convert(
                    targetRect.inset(by: areaDraggingOverlay.outerInsets),
                    to: sceneActionEffectView
                )
                if sceneState.manipulatingOptions.shouldClip {
                    areaDraggingOverlay.frame = convertedRect
                        .intersection(sceneActionEffectView.bounds)
                } else {
                    areaDraggingOverlay.frame = convertedRect
                }
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
                            let oldRatio = annotatorPixelRect.ratio
                            let proportional = sceneState.isProportionalScaling

                            let newFrame = SceneScrollView.calculateRect(
                                beginLocation: fixedOpposite,
                                currentLocation: locInAction,
                                withRatio: oldRatio,
                                byProportionalScaling: proportional,
                                byCenteredScaling: false
                            )
                            areaDraggingOverlay.frame =
                                newFrame.inset(by: areaDraggingOverlay.outerInsets)

                            let newPixelRect = SceneScrollView.calculatePixelRect(
                                beginLocation: fixedOppositeCoord,
                                currentLocation: PixelCoordinate(
                                    x: Int(round(locInWrapper.x)),
                                    y: Int(round(locInWrapper.y))
                                ),
                                withRatio: oldRatio,
                                byProportionalScaling: proportional,
                                byCenteredScaling: false
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
        updateDraggingAppearance(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseDragged) && $0.order.contains(.before) })
            .forEach({ $0.target?.mouseDragged(with: event) })
        internalMouseDragged(at: .left, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.leftMouseDragged) && $0.order.contains(.after) })
            .forEach({ $0.target?.mouseDragged(with: event) })
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDragged) && $0.order.contains(.before) })
            .forEach({ $0.target?.rightMouseDragged(with: event) })
        internalMouseDragged(at: .right, withEvent: event)
        sceneEventObservers
            .filter({ $0.types.contains(.rightMouseDragged) && $0.order.contains(.after) })
            .forEach({ $0.target?.rightMouseDragged(with: event) })
    }
    
    override func otherMouseDragged(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseDragged) && $0.order.contains(.before) })
            .forEach({ $0.target?.otherMouseDragged(with: event) })
        sceneEventObservers
            .filter({ $0.types.contains(.otherMouseDragged) && $0.order.contains(.after) })
            .forEach({ $0.target?.otherMouseDragged(with: event) })
    }
    
    override func scrollWheel(with event: NSEvent) {
        sceneEventObservers
            .filter({ $0.types.contains(.scrollWheel) && $0.order.contains(.before) })
            .forEach({ $0.target?.scrollWheel(with: event) })
        
        if !event.momentumPhase.isEmpty || !event.phase.isEmpty {
            // magic trackpad or magic mouse
            super.scrollWheel(with: event)
        } else {
            // traditional mouse
            if let centerPoint = documentView?.convert(event.locationInWindow, from: nil) {
                let linearVal = CGFloat(log2(magnification))
                var linearDeltaY = event.scrollingDeltaY * 0.01
                if !event.hasPreciseScrollingDeltas {
                    linearDeltaY *= verticalLineScroll
                }
                setMagnification(CGFloat(pow(2, linearVal + linearDeltaY)), centeredAt: centerPoint)
            }
        }
        
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
        
        NotificationCenter.default.post(
            name: SceneScrollView.willStartSmartMagnifyNotification,
            object: self
        )
        NSAnimationContext.runAnimationGroup({ _ in
            super.smartMagnify(with: event)
        }) { [unowned self] in
            NotificationCenter.default.post(
                name: SceneScrollView.didEndSmartMagnifyNotification,
                object: self
            )
        }
        
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
    
    weak var trackingDelegate: SceneActionTracking!
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
    
    
    // MARK: - Event Processing
    
    private func alternatingDraggingType(
        _ type: SceneState.ManipulatingType,
        withEvent event: NSEvent
    ) -> SceneState.ManipulatingType {
        switch type {
        case .sceneDragging:
            if sceneState.manipulatingSide == .right {
                return isForceTouch ? .forbidden : type
            }
        default:
            break
        }
        return type
    }
    
    private func alternatingDraggingOptions(
        _ options: SceneState.ManipulatingOptions,
        withEvent event: NSEvent
    ) -> SceneState.ManipulatingOptions {
        var allowedOptions: SceneState.ManipulatingOptions = []
        switch sceneTool {
        case .magicCursor:
            allowedOptions = [.proportionalScaling, .centeredScaling]
        case .selectionArrow:
            allowedOptions = [.proportionalScaling]
        default:
            break
        }
        return options.intersection(allowedOptions)
    }
    
    private func beginAnnotatorDragging(with event: NSEvent) -> EditableOverlay? {
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
    
    private func updateDraggingAppearance(with event: NSEvent) {
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
    static var checkerboardImage: NSImage = {
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

