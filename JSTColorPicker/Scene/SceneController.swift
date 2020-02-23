//
//  SceneController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import Quartz

extension CGPoint {
    
    func toPixelCenterCGPoint() -> CGPoint {
        return CGPoint(x: floor(x) + 0.5, y: floor(y) + 0.5)
    }
    
    func offsetBy(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: x + point.x, y: y + point.y)
    }
    
    static prefix func -(_ point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
    
}

extension CGSize: Comparable {
    
    public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
        return lhs.width * lhs.height < rhs.width * rhs.height
    }
    
    static prefix func -(_ size: CGSize) -> CGSize {
        return CGSize(width: -size.width, height: -size.height)
    }
    
}

extension CGRect {

    func scaleToAspectFit(in rtarget: CGRect) -> CGFloat {
        // first try to match width
        let s = rtarget.width / self.width;
        // if we scale the height to make the widths equal, does it still fit?
        if self.height * s <= rtarget.height {
            return s
        }
        // no, match height instead
        return rtarget.height / self.height
    }

    func aspectFit(in rtarget: CGRect) -> CGRect {
        let s = scaleToAspectFit(in: rtarget)
        let w = width * s
        let h = height * s
        let x = rtarget.midX - w / 2
        let y = rtarget.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func scaleToAspectFit(around rtarget: CGRect) -> CGFloat {
        // fit in the target inside the rectangle instead, and take the reciprocal
        return 1 / rtarget.scaleToAspectFit(in: self)
    }

    func aspectFit(around rtarget: CGRect) -> CGRect {
        let s = scaleToAspectFit(around: rtarget)
        let w = width * s
        let h = height * s
        let x = rtarget.midX - w / 2
        let y = rtarget.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    func offsetBy(_ point: CGPoint) -> CGRect {
        return CGRect(origin: origin.offsetBy(point), size: size)
    }
    
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        // this method is mentioned by: https://developer.apple.com/documentation/appkit/nsscreen/1388360-devicedescription
        return deviceDescription[NSDeviceDescriptionKey.init(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

class SceneController: NSViewController {
    
    var sceneVisibleBounds: CGRect {
        return sceneClipView.bounds.intersection(wrapper.bounds)
    }
    
    var sceneMagnification: CGFloat {
        return max(min(sceneView.magnification, SceneController.maximumZoomingFactor), SceneController.minimumZoomingFactor)
    }
    
    weak var trackingDelegate: SceneTracking?
    weak var contentResponder: ContentResponder?
    internal weak var screenshot: Screenshot?
    internal var annotators: [Annotator] = []
    fileprivate var colorAnnotators: [ColorAnnotator] {
        return annotators.compactMap({ $0 as? ColorAnnotator })
    }
    fileprivate var areaAnnotators: [AreaAnnotator] {
        return annotators.compactMap({ $0 as? AreaAnnotator })
    }
    
    fileprivate static let minimumZoomingFactor: CGFloat = pow(2.0, -2)  // 0.25x
    fileprivate static let maximumZoomingFactor: CGFloat = pow(2.0, 7)  // 128x
    fileprivate static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0
    ]
    fileprivate static let minimumRecognizablePixelWidth: CGFloat = 10.0
    
    @IBOutlet weak var sceneView: SceneScrollView!
    @IBOutlet weak var sceneClipView: SceneClipView!
    @IBOutlet weak var sceneOverlayView: SceneScrollOverlayView!
    @IBOutlet weak var sceneOverlayTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var sceneOverlayLeadingConstraint: NSLayoutConstraint!
    
    fileprivate var horizontalRulerView: RulerView {
        return sceneView.horizontalRulerView as! RulerView
    }
    fileprivate var verticalRulerView: RulerView {
        return sceneView.verticalRulerView as! RulerView
    }
    fileprivate var wrapper: SceneImageWrapper {
        return sceneView.documentView as! SceneImageWrapper
    }
    fileprivate func isInsceneLocation(_ point: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(point)
    }
    fileprivate func isInscenePixelLocation(_ point: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(sceneView.convert(point, from: wrapper)) && sceneView.documentVisibleRect.contains(point)
    }
    fileprivate var windowActiveNotificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeController()
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            if self.windowFlagsChanged(with: event) {
                return nil
            }
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            if self.windowKeyDown(with: event) {
                return nil
            }
            return event
        }
        
        sceneClipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidScrollNotification(_:)), name: NSView.boundsDidChangeNotification, object: sceneClipView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillStartLiveMagnifyNotification(_:)), name: NSScrollView.willStartLiveMagnifyNotification, object: sceneView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEndLiveMagnifyNotification(_:)), name: NSScrollView.didEndLiveMagnifyNotification, object: sceneView)
        windowActiveNotificationToken = NotificationCenter.default.observe(name: NSWindow.didResignKeyNotification, object: view.window) { [unowned self] notification in
            self.useSelectedTrackingTool()
        }
    }
    
    fileprivate func renderImage(_ image: PixelImage) {
        let imageView = SceneImageView()
        imageView.editable = false
        imageView.autoresizes = false
        imageView.hasVerticalScroller = false
        imageView.hasHorizontalScroller = false
        imageView.doubleClickOpensImageEditPanel = false
        imageView.supportsDragAndDrop = false
        imageView.currentToolMode = IKToolModeNone
        
        let imageProps = CGImageSourceCopyPropertiesAtIndex(image.imageSourceRep, 0, nil)
        imageView.setImage(image.imageRep, imageProperties: imageProps as? [AnyHashable : Any])
        
        let imageSize = image.size
        let initialRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)  // .aspectFit(in: sceneView.bounds)
        imageView.frame = initialRect
        imageView.zoomImageToFit(imageView)
        
        sceneView.trackingDelegate = self
        sceneView.trackingToolDelegate = self
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = true
        
        let wrapper = SceneImageWrapper(frame: initialRect)
        wrapper.rulerViewClient = self
        let grid = SceneImageGrid(frame: initialRect)
        wrapper.addSubview(grid)
        wrapper.addSubview(imageView)
        sceneView.documentView = wrapper
        sceneView.verticalRulerView?.clientView = wrapper
        sceneView.horizontalRulerView?.clientView = wrapper
        
        useSelectedTrackingTool()
    }
    
    fileprivate var trackingTool: TrackingTool {
        get {
            return sceneView.trackingTool
        }
        set {
            sceneView.trackingTool = newValue
        }
    }
    
    fileprivate var selectedTrackingTool: TrackingTool {
        get {
            guard let tool = view.window?.toolbar?.selectedItemIdentifier?.rawValue else { return .arrow }
            return TrackingTool(rawValue: tool) ?? .arrow
        }
    }
    
    fileprivate var nextMagnificationFactor: CGFloat? {
        get {
            return SceneController.zoomingFactors.first(where: { $0 > sceneView.magnification })
        }
    }
    
    fileprivate var prevMagnificationFactor: CGFloat? {
        get {
            return SceneController.zoomingFactors.reversed().first(where: { $0 < sceneView.magnification })
        }
    }
    
    fileprivate var canMagnify: Bool {
        get {
            if !sceneView.allowsMagnification {
                return false
            }
            if sceneView.magnification >= SceneController.maximumZoomingFactor {
                return false
            }
            return true
        }
    }
    
    fileprivate var canMinify: Bool {
        get {
            if !sceneView.allowsMagnification {
                return false
            }
            if sceneView.magnification <= SceneController.minimumZoomingFactor {
                return false
            }
            return true
        }
    }
    
    fileprivate func cursorClicked(at location: CGPoint) -> Bool {
        _ = try? addContentItem(of: PixelCoordinate(location))
        return true
    }
    
    fileprivate func rightCursorClicked(at location: CGPoint) -> Bool {
        let locationInMask = sceneOverlayView.convert(location, from: wrapper)
        
        var annotatorView: AnnotatorOverlay?
        if !(annotatorView != nil) {
            annotatorView = sceneOverlayView.subviews.compactMap({ $0 as? ColorAnnotatorOverlay }).reversed().first(where: { $0.frame.contains(locationInMask) })
        }
        if !(annotatorView != nil) {
            annotatorView = sceneOverlayView.subviews.compactMap({ $0 as? AreaAnnotatorOverlay }).reversed().first(where: { $0.frame.contains(locationInMask) })
        }
        
        if let annotatorView = annotatorView {
            annotators.filter({ $0.view === annotatorView }).forEach({ _ = try? deleteContentItem($0.pixelItem) })
            return true
        }
        
        _ = try? deleteContentItem(of: PixelCoordinate(location))
        return true
    }
    
    fileprivate func magnifyToolClicked(at location: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            if isInscenePixelLocation(location) {
                self.hideSceneOverlay()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(next, centeredAt: location)
                }) { [unowned self] in
                    self.showSceneOverlay()
                    self.sceneBoundsChanged()
                }
            } else {
                self.hideSceneOverlay()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = next
                }) { [unowned self] in
                    self.showSceneOverlay()
                    self.sceneBoundsChanged()
                }
            }
            return true
        }
        return false
    }
    
    fileprivate func minifyToolClicked(at location: CGPoint) -> Bool {
        if !canMinify {
            return false
        }
        if let prev = prevMagnificationFactor {
            if isInscenePixelLocation(location) {
                self.hideSceneOverlay()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(prev, centeredAt: location)
                }) { [unowned self] in
                    self.showSceneOverlay()
                    self.sceneBoundsChanged()
                }
            } else {
                self.hideSceneOverlay()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = prev
                }) { [unowned self] in
                    self.showSceneOverlay()
                    self.sceneBoundsChanged()
                }
            }
            return true
        }
        return false
    }
    
    override func mouseUp(with event: NSEvent) {
        var handled = false
        if sceneView.isBeingManipulated && !sceneView.isBeingDragged {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if isInscenePixelLocation(loc) {
                if trackingTool == .cursor {
                    handled = cursorClicked(at: loc)
                }
                else if trackingTool == .magnify {
                    handled = magnifyToolClicked(at: loc)
                }
                else if trackingTool == .minify {
                    handled = minifyToolClicked(at: loc)
                }
            }
        }
        if !handled {
            super.mouseUp(with: event)
        }
    }
    
    override func rightMouseUp(with event: NSEvent) {
        var handled = false
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        if isInscenePixelLocation(loc) {
            if trackingTool == .cursor {
                handled = rightCursorClicked(at: loc)
            }
        }
        if !handled {
            super.rightMouseUp(with: event)
        }
    }
    
    fileprivate func windowFlagsChanged(with event: NSEvent) -> Bool {
        guard let window = view.window, window.isKeyWindow else { return false }  // important
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.shift) {
        case [.option]:
            return useOptionModifiedTrackingTool()
        case [.command]:
            return useCommandModifiedTrackingTool()
        default:
            return useSelectedTrackingTool()
        }
    }
    
    @discardableResult
    fileprivate func useOptionModifiedTrackingTool() -> Bool {
        if sceneView.isBeingManipulated { return false }
        if trackingTool == .magnify {
            trackingTool = .minify
            return true
        }
        else if trackingTool == .minify {
            trackingTool = .magnify
            return true
        }
        return false
    }
    
    @discardableResult
    fileprivate func useCommandModifiedTrackingTool() -> Bool {
        if sceneView.isBeingManipulated { return false }
        if trackingTool == .magnify || trackingTool == .minify || trackingTool == .move {
            trackingTool = .cursor
            return true
        }
        return false
    }
    
    @discardableResult
    fileprivate func useSelectedTrackingTool() -> Bool {
        trackingTool = selectedTrackingTool
        return true
    }
    
    @discardableResult
    fileprivate func shortcutMoveCursorOrScene(by direction: NSEvent.SpecialKey, for pixelDistance: CGFloat, from pixelLocation: CGPoint) -> Bool {
        guard isInscenePixelLocation(pixelLocation) else { return false }
        
        var wrapperDelta = CGSize.zero
        switch direction {
        case NSEvent.SpecialKey.upArrow:
            wrapperDelta.height -= pixelDistance
        case NSEvent.SpecialKey.downArrow:
            wrapperDelta.height += pixelDistance
        case NSEvent.SpecialKey.leftArrow:
            wrapperDelta.width  -= pixelDistance
        case NSEvent.SpecialKey.rightArrow:
            wrapperDelta.width  += pixelDistance
        default: break
        }
        
        let windowDelta = wrapper.convert(wrapperDelta, to: nil)  // to window coordinate
        guard abs(windowDelta.width + windowDelta.height) > SceneController.minimumRecognizablePixelWidth else { return false }
        
        var targetWrapperPoint = pixelLocation.toPixelCenterCGPoint()
        targetWrapperPoint.x += wrapperDelta.width
        targetWrapperPoint.y += wrapperDelta.height
        
        guard wrapper.bounds.contains(targetWrapperPoint) else {
            return false
        }
        
        guard isInscenePixelLocation(targetWrapperPoint) else {
            let clipDelta = wrapper.convert(wrapperDelta, to: sceneClipView)  // force to positive
            
            var clipOrigin = sceneClipView.bounds.origin
            if wrapperDelta.width > 0 {
                clipOrigin.x += clipDelta.width
            } else {
                clipOrigin.x -= clipDelta.width
            }
            if wrapperDelta.height > 0 {
                clipOrigin.y += clipDelta.height
            } else {
                clipOrigin.y -= clipDelta.height
            }
            
            sceneClipView.animator().setBoundsOrigin(clipOrigin)
            return true
        }
        
        guard let window = wrapper.window else { return false }
        guard let mainScreen = window.screen else { return false }
        guard let displayID = mainScreen.displayID else { return false }
        
        let windowPoint = wrapper.convert(targetWrapperPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        let screenFrame = mainScreen.frame
        let targetDisplayMousePosition = CGPoint(x: screenPoint.x - screenFrame.origin.x, y: screenFrame.size.height - (screenPoint.y - screenFrame.origin.y))
        
        CGDisplayHideCursor(kCGNullDirectDisplay)
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayMoveCursorToPoint(displayID, targetDisplayMousePosition)
        /* perform your application’s main loop */
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(kCGNullDirectDisplay)
        
        trackColorChanged(self, at: PixelCoordinate(targetWrapperPoint))
        return true
    }
    
    @discardableResult
    fileprivate func shortcutCopyPixelColor(at pixelLocation: CGPoint) -> Bool {
        guard let screenshot = screenshot else { return false }
        guard isInscenePixelLocation(pixelLocation) else { return false }
        screenshot.export.copyPixelColor(at: PixelCoordinate(pixelLocation))
        return true
    }
     
    fileprivate func windowKeyDown(with event: NSEvent) -> Bool {
        guard let window = view.window, window.isKeyWindow else { return false }  // important
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            
            var distance: CGFloat = 1.0
            if flags.contains(.control) {
                distance = 100.0
            }
            else if flags.contains(.shift) {
                distance = 10.0
            }
            
            if let specialKey = event.specialKey {
                if specialKey == .upArrow || specialKey == .downArrow || specialKey == .leftArrow || specialKey == .rightArrow {
                    return shortcutMoveCursorOrScene(by: specialKey, for: distance, from: loc)
                }
                else if specialKey == .enter || specialKey == .carriageReturn {
                    return cursorClicked(at: loc)
                }
                else if specialKey == .delete {
                    return rightCursorClicked(at: loc)
                }
            }
            else if let characters = event.characters {
                if characters.contains("-") {
                    return minifyToolClicked(at: loc)
                }
                else if characters.contains("=") {
                    return magnifyToolClicked(at: loc)
                }
                else if characters.contains("`") {
                    return shortcutCopyPixelColor(at: loc)
                }
            }
            
        }
        
        return false
    }
    
    deinit {
        debugPrint("- [SceneController deinit]")
    }
    
}

extension SceneController: ScreenshotLoader {
    
    func initializeController() {
        sceneView.minMagnification = SceneController.minimumZoomingFactor
        sceneView.maxMagnification = SceneController.maximumZoomingFactor
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = false
        sceneView.usesPredominantAxisScrolling = false
        
        let wrapper = SceneImageWrapper()
        wrapper.rulerViewClient = self
        sceneView.documentView = wrapper
        sceneView.verticalRulerView?.clientView = wrapper
        sceneView.horizontalRulerView?.clientView = wrapper
        
        // `sceneView.documentCursor` is not what we need, see `SceneScrollView` for a more accurate implementation of cursor appearance
        sceneClipView.contentInsets = NSEdgeInsetsMake(240, 240, 240, 240)
        
        sceneOverlayTopConstraint.constant = SceneScrollView.alternativeBoundsOrigin.y
        sceneOverlayLeadingConstraint.constant = SceneScrollView.alternativeBoundsOrigin.x
        useSelectedTrackingTool()
    }
    
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        guard let image = screenshot.image else {
            throw ScreenshotError.invalidImage
        }
        renderImage(image)
        guard let content = screenshot.content else {
            throw ScreenshotError.invalidContent
        }
        try loadAnnotators(from: content)
    }
    
}

extension SceneController: SceneTracking {
    
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) {
        trackingDelegate?.trackSceneBoundsChanged(sender, to: rect, of: magnification)
    }
    
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingDelegate?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: Any, to rect: PixelRect) {
        trackingDelegate?.trackAreaChanged(sender, to: rect)
    }
    
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect())
    }
    
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) {
        _ = try? addContentItem(of: rect)
    }
    
    fileprivate func sceneBoundsChanged() {
        trackSceneBoundsChanged(self, to: sceneVisibleBounds, of: sceneMagnification)
    }
    
}

extension NSRect {
    func inset(by insets: NSEdgeInsets) -> NSRect {
        return NSRect(x: origin.x + insets.left, y: origin.y + insets.bottom, width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom)
    }
}

extension SceneController: ToolbarResponder {
    
    func useCursorAction(_ sender: Any?) {
        trackingTool = .cursor
    }
    
    func useMagnifyToolAction(_ sender: Any?) {
        trackingTool = .magnify
    }
    
    func useMinifyToolAction(_ sender: Any?) {
        trackingTool = .minify
    }
    
    func useMoveToolAction(_ sender: Any?) {
        trackingTool = .move
    }
    
    func fitWindowAction(_ sender: Any?) {
        sceneMagnify(toFit: wrapper.bounds)
    }
    
    func fillWindowAction(_ sender: Any?) {
        sceneMagnify(toFit: sceneView.bounds.aspectFit(in: wrapper.bounds))
    }
    
    fileprivate func sceneMagnify(toFit rect: CGRect) {
        NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
            self.sceneView.animator().magnify(toFit: rect)
        }) { [unowned self] in
            self.sceneBoundsChanged()
        }
    }
    
}

extension SceneController: TrackingToolDelegate {
    
    func trackingToolEnabled(_ sender: Any, tool: TrackingTool) -> Bool {
        if tool == .magnify {
            return canMagnify
        }
        else if tool == .minify {
            return canMinify
        }
        return true
    }
    
}

extension SceneController: AnnotatorManager {
    
    @objc fileprivate func sceneWillStartLiveMagnifyNotification(_ notification: NSNotification) {
        hideSceneOverlay()
    }
    
    @objc fileprivate func sceneDidEndLiveMagnifyNotification(_ notification: NSNotification) {
        showSceneOverlay()
    }
    
    @objc fileprivate func sceneDidScrollNotification(_ notification: NSNotification) {
        if !sceneOverlayView.isHidden {
            updateAnnotatorBounds()
        }
        sceneBoundsChanged()
    }
    
    fileprivate func hideSceneOverlay() {
        sceneOverlayView.isHidden = true
    }
    
    fileprivate func showSceneOverlay() {
        sceneOverlayView.isHidden = false
        updateAnnotatorBounds()
    }
    
    fileprivate func updateFrame(of annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            annotator.view.isSmallArea = true
            let pointInMask = sceneView.convert(annotator.pixelColor.coordinate.toCGPoint().toPixelCenterCGPoint(), from: wrapper).offsetBy(-SceneScrollView.alternativeBoundsOrigin)
            annotator.view.frame = CGRect(origin: pointInMask, size: annotator.view.defaultSize).offsetBy(annotator.view.defaultOffset)
        }
        else if let annotator = annotator as? AreaAnnotator {
            let rectInMask = sceneView.convert(annotator.pixelArea.rect.toCGRect(), from: wrapper).offsetBy(-SceneScrollView.alternativeBoundsOrigin)
            // if smaller than default size
            if rectInMask.size < annotator.view.defaultSize {
                annotator.view.isSmallArea = true
                annotator.view.frame = CGRect(origin: rectInMask.center, size: annotator.view.defaultSize).offsetBy(annotator.view.defaultOffset)
            } else {
                annotator.view.isSmallArea = false
                annotator.view.frame = rectInMask.inset(by: annotator.view.outerInsets)
            }
        }
    }
    
    fileprivate func updateAnnotatorBounds() {
        annotators.forEach { (annotator) in
            updateFrame(of: annotator)
        }
    }
    
    fileprivate func loadRulerMarkers(for annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            let coordinate = annotator.pixelColor.coordinate
            
            let markerCoordinateH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(coordinate.x), image: RulerMarker.horizontalImage, imageOrigin: RulerMarker.horizontalOrigin)
            markerCoordinateH.type = .horizontal
            markerCoordinateH.position = .origin
            markerCoordinateH.coordinate = coordinate
            markerCoordinateH.annotator = annotator
            annotator.rulerMarkers.append(markerCoordinateH)
            
            let markerCoordinateV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(coordinate.y), image: RulerMarker.verticalImage, imageOrigin: RulerMarker.verticalOrigin)
            markerCoordinateV.type = .vertical
            markerCoordinateV.position = .origin
            markerCoordinateV.coordinate = coordinate
            markerCoordinateV.annotator = annotator
            annotator.rulerMarkers.append(markerCoordinateV)
        }
        else if let annotator = annotator as? AreaAnnotator {
            let rect = annotator.pixelArea.rect
            let origin = rect.origin
            let opposite = rect.opposite
            
            let markerOriginH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(origin.x), image: RulerMarker.horizontalImage, imageOrigin: RulerMarker.horizontalOrigin)
            markerOriginH.type = .horizontal
            markerOriginH.position = .origin
            markerOriginH.coordinate = origin
            markerOriginH.annotator = annotator
            annotator.rulerMarkers.append(markerOriginH)
            
            let markerOriginV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(origin.y), image: RulerMarker.verticalImage, imageOrigin: RulerMarker.verticalOrigin)
            markerOriginV.type = .vertical
            markerOriginV.position = .origin
            markerOriginV.coordinate = origin
            markerOriginV.annotator = annotator
            annotator.rulerMarkers.append(markerOriginV)
            
            let markerOppositeH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(opposite.x), image: RulerMarker.horizontalImage, imageOrigin: RulerMarker.horizontalOrigin)
            markerOppositeH.type = .horizontal
            markerOppositeH.position = .opposite
            markerOppositeH.coordinate = opposite
            markerOppositeH.annotator = annotator
            annotator.rulerMarkers.append(markerOppositeH)
            
            let markerOppositeV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(opposite.y), image: RulerMarker.verticalImage, imageOrigin: RulerMarker.verticalOrigin)
            markerOppositeV.type = .vertical
            markerOppositeV.position = .opposite
            markerOppositeV.coordinate = opposite
            markerOppositeV.annotator = annotator
            annotator.rulerMarkers.append(markerOppositeV)
        }
    }
    
    fileprivate func unloadRulerMarkers(for annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.removeMarker($0) })
        annotator.rulerMarkers.removeAll()
    }
    
    fileprivate func reloadRulerMarkers(for annotator: Annotator) {
        unloadRulerMarkers(for: annotator)
        loadRulerMarkers(for: annotator)
    }
    
    fileprivate func showRulerMarkers(for annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.addMarker($0) })
    }
    
    fileprivate func hideRulerMarkers(for annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.removeMarker($0) })
    }
    
    func loadAnnotators(from content: Content) throws {
        addAnnotators(for: content.items)
    }
    
    func addAnnotators(for items: [ContentItem]) {
        items.forEach { (item) in
            guard !annotators.contains(where: { $0.pixelItem == item }) else { return }
            if let color = item as? PixelColor {
                addAnnotator(for: color)
            }
            else if let area = item as? PixelArea {
                addAnnotator(for: area)
            }
        }
        debugPrint("add annotators \(items)")
    }
    
    func addAnnotator(for color: PixelColor) {
        let annotator = ColorAnnotator(pixelItem: color.copy() as! PixelColor)
        loadRulerMarkers(for: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
        updateFrame(of: annotator)
    }
    
    func addAnnotator(for area: PixelArea) {
        let annotator = AreaAnnotator(pixelItem: area.copy() as! PixelArea)
        loadRulerMarkers(for: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
        updateFrame(of: annotator)
    }
    
    func updateAnnotator(for items: [ContentItem]) {
        let itemIDs = items.compactMap({ $0.id })
        let itemsToRemove = annotators.compactMap({ $0.pixelItem }).filter({ itemIDs.contains($0.id) })
        removeAnnotators(for: itemsToRemove)
        addAnnotators(for: items)
        highlightAnnotators(for: items, scrollTo: false)
    }
    
    func removeAnnotators(for items: [ContentItem]) {
        let annotatorsToRemove = annotators.filter({ items.contains($0.pixelItem) })
        annotatorsToRemove.forEach({ hideRulerMarkers(for: $0) })
        annotatorsToRemove.forEach({ $0.view.removeFromSuperview() })
        annotators.removeAll(where: { items.contains($0.pixelItem) })
        debugPrint("remove annotators \(items)")
    }
    
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool) {
        annotators.filter({ $0.isHighlighted }).forEach({
            $0.isHighlighted = false
            hideRulerMarkers(for: $0)
        })
        annotators.filter({ items.contains($0.pixelItem) }).forEach({
            $0.isHighlighted = true
            showRulerMarkers(for: $0)
            $0.view.bringToFront()
        })
        if scrollTo {  // scroll without changing magnification
            let item = annotators.first(where: { items.contains($0.pixelItem) })?.pixelItem
            if let color = item as? PixelColor {
                previewAction(self, centeredAt: color.coordinate)
            }
            else if let area = item as? PixelArea {
                previewAction(self, centeredAt: area.rect.origin)
            }
        }
        debugPrint("highlight annotators \(items), scroll = \(scrollTo)")
    }
    
}

extension SceneController: PreviewResponder {
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) {
        guard magnification >= SceneController.minimumZoomingFactor && magnification <= SceneController.maximumZoomingFactor else { return }
        if sceneOverlayView.isHidden != isChanging {
            if isChanging {
                hideSceneOverlay()
            } else {
                showSceneOverlay()
            }
        }
        sceneView.magnification = magnification
    }
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        let centerPoint = coordinate.toCGPoint().toPixelCenterCGPoint()
        if !isInscenePixelLocation(centerPoint) {
            var point = sceneView.convert(centerPoint, from: wrapper)
            point.x -= sceneView.bounds.width / 2.0
            point.y -= sceneView.bounds.height / 2.0
            let clipCenterPoint = sceneClipView.convert(point, from: sceneView)
            sceneClipView.animator().setBoundsOrigin(clipCenterPoint)
        }
    }
    
}

extension SceneController: ContentResponder {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentResponder?.addContentItem(of: coordinate)
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        return try contentResponder?.addContentItem(of: rect)
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentResponder?.updateContentItem(item, to: coordinate)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        return try contentResponder?.updateContentItem(item, to: rect)
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentResponder?.deleteContentItem(of: coordinate)
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentResponder?.deleteContentItem(item)
    }
    
}

extension SceneController: RulerViewClient {
    
    func rulerView(_ ruler: RulerView?, shouldAdd marker: RulerMarker) -> Bool {
        return false
    }
    
    func rulerView(_ ruler: RulerView?, shouldMove marker: RulerMarker) -> Bool {
        return true
    }
    
    func rulerView(_ ruler: RulerView?, shouldRemove marker: RulerMarker) -> Bool {
        return false
    }
    
    func rulerView(_ ruler: RulerView?, willMove marker: RulerMarker, toLocation location: Int) -> Int {
        return location
    }
    
    func rulerView(_ ruler: RulerView?, didAdd marker: RulerMarker) {
        
    }
    
    func rulerView(_ ruler: RulerView?, didMove marker: RulerMarker) {
        
        var coordinate = marker.coordinate
        if marker.type == .horizontal {
            coordinate.x = Int(round(marker.markerLocation))
        }
        else if marker.type == .vertical {
            coordinate.y = Int(round(marker.markerLocation))
        }
        
        guard coordinate != marker.coordinate else { return }
        let item = marker.annotator?.pixelItem.copy()
        if let item = item as? PixelColor {
            if let _ = try? updateContentItem(item, to: coordinate) {
                // do nothing
                return
            }
        }
        else if let item = item as? PixelArea {
            var rect: PixelRect?
            if marker.position == .origin {
                rect = PixelRect(coordinate1: coordinate, coordinate2: item.rect.opposite)
            }
            else if marker.position == .opposite {
                rect = PixelRect(coordinate1: item.rect.origin, coordinate2: coordinate)
            }
            if let rect = rect {
                if let _ = try? updateContentItem(item, to: rect) {
                    // do nothing
                    return
                }
            }
        }
        
        if marker.type == .horizontal {
            marker.markerLocation = CGFloat(marker.coordinate.x)
        }
        else if marker.type == .vertical {
            marker.markerLocation = CGFloat(marker.coordinate.y)
        }
        
    }
    
    func rulerView(_ ruler: RulerView?, didRemove marker: RulerMarker) {
        
    }
    
}
