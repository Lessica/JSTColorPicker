//
//  SceneScrollView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension CGPoint {
    
    func distanceTo(_ point: CGPoint) -> CGFloat {
        let deltaX = abs(x - point.x)
        let deltaY = abs(y - point.y)
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
    
    public static var null: CGPoint {
        return CGPoint(x: CGFloat.infinity, y: CGFloat.infinity)
    }
    
    public var isNull: Bool {
        return self.x == CGFloat.infinity || self.y == CGFloat.infinity
    }
    
}

extension CGRect {
    
    init(point1: CGPoint, point2: CGPoint) {
        self.init(origin: CGPoint(x: min(point1.x, point2.x), y: min(point1.y, point2.y)), size: CGSize(width: abs(point2.x - point1.x), height: abs(point2.y - point1.y)))
    }
    
}

extension NSView {
    
    func bringToFront() {
        guard let sView = superview else {
            return
        }
        removeFromSuperview()
        sView.addSubview(self)
    }
    
}

extension NSScrollView {
    
    func convertFromDocumentView(_ rect: CGRect) -> CGRect {
        return convert(rect, from: documentView)
    }
    
    func convertFromDocumentView(_ size: CGSize) -> CGSize {
        return convert(size, from: documentView)
    }
    
    func convertFromDocumentView(_ point: CGPoint) -> CGPoint {
        return convert(point, from: documentView)
    }
    
    func convertToDocumentView(_ rect: CGRect) -> CGRect {
        return convert(rect, to: documentView)
    }
    
    func convertToDocumentView(_ size: CGSize) -> CGSize {
        return convert(size, to: documentView)
    }
    
    func convertToDocumentView(_ point: CGPoint) -> CGPoint {
        return convert(point, to: documentView)
    }
    
}

enum SceneManipulatingType {
    case none
    case generic
    case basicDragging
    case areaDragging
    
    public static func type(for tool: TrackingTool) -> SceneManipulatingType {
        switch tool {
        case .cursor, .magnify:
            return .areaDragging
        case .move:
            return .basicDragging
        default:
            return .none
        }
    }
    public var isManipulating: Bool {
        return self != .none
    }
    public var isDragging: Bool {
        if self == .basicDragging || self == .areaDragging {
            return true
        }
        return false
    }
}

struct SceneManipulatingState {
    public var type: SceneManipulatingType = .none
    private var internalStage: Int = 0
    private var internalBeginLocation: CGPoint = .null
    
    public var stage: Int {
        get {
            return type != .none ? internalStage : 0
        }
        set {
            internalStage = newValue
        }
    }
    public var beginLocation: CGPoint {
        get {
            return type != .none ? internalBeginLocation : .null
        }
        set {
            internalBeginLocation = newValue
        }
    }
    public var isManipulating: Bool {
        return type.isManipulating
    }
    public var isDragging: Bool {
        return type.isDragging
    }
}

class SceneScrollView: NSScrollView {
    
    public var state = SceneManipulatingState()
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
    fileprivate var minimumDraggingDistance: CGFloat {
        return enableForceTouch ? 6.0 : 3.0
    }
    fileprivate func requiredEventStageFor(_ tool: TrackingTool) -> Int {
        switch tool {
        case .cursor, .magnify:
            return enableForceTouch ? 2 : 0
        default:
            return 0
        }
    }
    
    fileprivate var wrapper: SceneImageWrapper {
        return documentView as! SceneImageWrapper
    }
    fileprivate var trackingArea: NSTrackingArea?
    fileprivate var trackingCoordinate = PixelCoordinate.null
    public weak var trackingDelegate: SceneTracking?
    public weak var trackingToolDelegate: TrackingToolDelegate?
    public var trackingTool: TrackingTool = .cursor {
        didSet {
            updateCursorAppearance()
        }
    }
    
    public var visibleRectExcludingRulers: CGRect {
        let rect = visibleRect
        return CGRect(x: rect.minX + alternativeBoundsOrigin.x, y: rect.minY + alternativeBoundsOrigin.y, width: rect.width - alternativeBoundsOrigin.x, height: rect.height - alternativeBoundsOrigin.y)
    }
    fileprivate var isMouseInside: Bool {
        if let locationInWindow = window?.mouseLocationOutsideOfEventStream {
            let loc = convert(locationInWindow, from: nil)
            if visibleRectExcludingRulers.contains(loc) {
                return true
            }
        }
        return false
    }
    
    public var alternativeBoundsOrigin: CGPoint {
        if drawRulersInScene {
            return CGPoint(x: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView, y: SceneScrollView.rulerThickness + SceneScrollView.reservedThicknessForMarkers + SceneScrollView.reservedThicknessForAccessoryView)
        }
        return CGPoint.zero
    }
    fileprivate static let rulerThickness: CGFloat = 16.0
    fileprivate static let reservedThicknessForMarkers: CGFloat = 15.0
    fileprivate static let reservedThicknessForAccessoryView: CGFloat = 0.0
    
    fileprivate lazy var draggingOverlay: DraggingOverlay = {
        let view = DraggingOverlay()
        view.wantsLayer = true
        view.isHidden = true
        return view
    }()
    fileprivate var overlayPixelRect: PixelRect {
        let rect = convert(draggingOverlay.frame, to: wrapper).intersection(wrapper.bounds)
        guard !rect.isNull else { return PixelRect.null }
        return PixelRect(CGRect(origin: rect.origin, size: CGSize(width: ceil(ceil(rect.maxX) - floor(rect.minX)), height: ceil(ceil(rect.maxY) - floor(rect.minY)))))
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        SceneScrollView.rulerViewClass = RulerView.self
        contentInsets = NSEdgeInsetsZero
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic
        usesPredominantAxisScrolling = false
        
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
        addSubview(draggingOverlay)
    }
    
    fileprivate func reloadSceneRulers() {
        if drawRulersInScene {
            rulersVisible = true
        }
        else {
            rulersVisible = false
        }
    }
    
    fileprivate func reloadSceneBackground() {
        if drawSceneBackground {
            backgroundColor = NSColor.init(patternImage: NSImage(named: "JSTBackgroundPattern")!)
        }
        else {
            backgroundColor = NSColor.controlBackgroundColor
        }
    }
    
    fileprivate func shouldBeginAreaDragging(for event: NSEvent) -> Bool {
        let shiftPressed = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        if enableForceTouch {
            return shiftPressed || state.stage >= requiredEventStageFor(trackingTool)
        } else {
            return shiftPressed
        }
    }
    
    fileprivate func trackMovingOrDragging(with event: NSEvent) {
        if state.type != .basicDragging {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if wrapper.bounds.contains(loc) {
                let currentCoordinate = PixelCoordinate(loc)
                if currentCoordinate != trackingCoordinate {
                    trackingCoordinate = currentCoordinate
                    trackingDelegate?.trackColorChanged(self, at: currentCoordinate)
                }
            }
        }
        if state.type == .areaDragging {
            let draggingArea = overlayPixelRect
            if !draggingArea.isNull {
                trackingDelegate?.trackAreaChanged(self, to: draggingArea)
            }
        }
    }
    
    fileprivate func trackDidEndDragging(with event: NSEvent) {
        if state.type == .areaDragging {
            let draggingArea = overlayPixelRect
            if draggingArea.size > PixelSize(width: 1, height: 1) {
                if trackingTool == .cursor {
                    trackingDelegate?.trackCursorDragged(self, to: draggingArea)
                }
                else if trackingTool == .magnify {
                    trackingDelegate?.trackMagnifyToolDragged(self, to: draggingArea)
                }
            }
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
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override func mouseEntered(with event: NSEvent) {
        trackMovingOrDragging(with: event)
        updateCursorAppearance()
    }
    
    override func mouseMoved(with event: NSEvent) {
        trackMovingOrDragging(with: event)
        updateCursorAppearance()
    }
    
    override func mouseExited(with event: NSEvent) {
        trackMovingOrDragging(with: event)
        NSCursor.arrow.set()
    }
    
    override func pressureChange(with event: NSEvent) {
        if enableForceTouch && event.stage > state.stage {
            state.stage = event.stage
        }
        super.pressureChange(with: event)
    }
    
    fileprivate func updateCursorAppearance() {
        guard let delegate = trackingToolDelegate else { return }
        if !isMouseInside { return }
        if delegate.trackingToolEnabled(self, tool: trackingTool) {
            if !state.isManipulating {
                trackingTool.currentCursor.set()
            } else {
                trackingTool.highlightCursor.set()
            }
        } else {
            trackingTool.disabledCursor.set()
        }
    }
    
    fileprivate func updateDraggingLayerAppearance(for event: NSEvent) {
        if state.type == .areaDragging {
            if draggingOverlay.isHidden {
                draggingOverlay.bringToFront()
                draggingOverlay.isHidden = false
            }
        } else {
            draggingOverlay.isHidden = true
            draggingOverlay.frame = CGRect.zero
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            state.type = .generic
            state.stage = 0
            state.beginLocation = currentLocation
            trackMovingOrDragging(with: event)
        }
        
        updateDraggingLayerAppearance(for: event)
        updateCursorAppearance()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        let currentLocation = convert(event.locationInWindow, from: nil)
        if visibleRectExcludingRulers.contains(currentLocation) {
            trackMovingOrDragging(with: event)
            if state.isDragging {
                trackDidEndDragging(with: event)
            }
        }
        
        state.type = .none
        state.stage = 0
        state.beginLocation = .null
        
        updateDraggingLayerAppearance(for: event)
        updateCursorAppearance()
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        guard !state.beginLocation.isNull else { return }
        let currentLocation = convert(event.locationInWindow, from: nil)
        if currentLocation.distanceTo(state.beginLocation) >= minimumDraggingDistance {
            let type = SceneManipulatingType.type(for: trackingTool)
            if state.type != type {
                if type == .areaDragging {
                    if shouldBeginAreaDragging(for: event) {
                        state.type = .areaDragging
                    } else {
                        state.type = .none
                    }
                }
                else {
                    state.type = type
                }
            }
        }
        
        if state.isDragging {
            if state.type == .basicDragging {
                let origin = contentView.bounds.origin
                let delta = CGPoint(x: -event.deltaX / magnification, y: -event.deltaY / magnification)
                contentView.setBoundsOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            }
            else if state.type == .areaDragging {
                let rect = CGRect(point1: state.beginLocation, point2: convert(event.locationInWindow, from: nil)).inset(by: draggingOverlay.outerInsets).intersection(bounds)
                draggingOverlay.frame = rect
            }
            trackMovingOrDragging(with: event)
        }
        
        updateDraggingLayerAppearance(for: event)
        updateCursorAppearance()
    }
    
    override func reflectScrolledClipView(_ cView: NSClipView) {
        super.reflectScrolledClipView(cView)
        trackingDelegate?.trackSceneBoundsChanged(self, to: cView.bounds.intersection(wrapper.bounds), of: max(min(magnification, maxMagnification), minMagnification))
    }
    
}
