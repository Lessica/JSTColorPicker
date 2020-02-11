//
//  PickerSceneViewController.swift
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
    
    fileprivate static let minimumZoomingFactor: CGFloat = pow(2.0, -2)  // 0.25x
    fileprivate static let maximumZoomingFactor: CGFloat = pow(2.0, 7)  // 128x
    fileprivate static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0
    ]
    fileprivate static let minimumRecognizablePixelWidth: CGFloat = 10.0
    
    weak var trackingObject: SceneTracking?
    internal weak var screenshot: Screenshot?
    internal var annotators: [Annotator] = []
    fileprivate var colorAnnotators: [ColorAnnotator] {
        return annotators.compactMap({ $0 as? ColorAnnotator })
    }
    fileprivate var areaAnnotators: [AreaAnnotator] {
        return annotators.compactMap({ $0 as? AreaAnnotator })
    }
    @IBOutlet weak var sceneView: SceneScrollView!
    @IBOutlet weak var sceneClipView: SceneClipView!
    @IBOutlet weak var sceneOverlayView: SceneScrollOverlayView!
    fileprivate var wrapper: SceneImageWrapper {
        return sceneView.documentView as! SceneImageWrapper
    }
    fileprivate var windowActiveNotificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
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
        
        sceneView.backgroundColor = NSColor.init(patternImage: NSImage(named: "JSTBackgroundPattern")!)
        sceneView.contentInsets = NSEdgeInsetsZero
        sceneView.hasVerticalRuler = true
        sceneView.hasHorizontalRuler = true
        sceneView.rulersVisible = true
        sceneView.verticalScrollElasticity = .automatic
        sceneView.horizontalScrollElasticity = .automatic
        sceneView.usesPredominantAxisScrolling = false  // TODO: set this in menu
        sceneView.verticalRulerView?.measurementUnits = .points
        sceneView.horizontalRulerView?.measurementUnits = .points
        // `sceneView.documentCursor` is not what we need, see `SceneScrollView` for a more accurate implementation of cursor appearance
        sceneClipView.contentInsets = NSEdgeInsetsMake(240, 240, 240, 240)
        resetController()
        
        sceneClipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidScrollNotification(_:)), name: NSView.boundsDidChangeNotification, object: sceneClipView)
        windowActiveNotificationToken = NotificationCenter.default.observe(name: NSWindow.didResignKeyNotification, object: view.window) { [unowned self] notification in
            _ = self.useSelectedTrackingTool()
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
        
        let imageSize = image.pixelImageRep.size()
        let initialRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)  // .aspectFit(in: sceneView.bounds)
        imageView.frame = initialRect
        imageView.zoomImageToFit(imageView)
        
        sceneView.trackingDelegate = self
        sceneView.trackingToolDelegate = self
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = true
        let wrapper = SceneImageWrapper(frame: initialRect)
        wrapper.addSubview(imageView)
        sceneView.documentView = wrapper
        
        _ = useSelectedTrackingTool()
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
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // not implemented
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        // not implemented
    }
    
    fileprivate func cursorClicked(at location: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(location) { return false }
        trackCursorClicked(self, at: PixelCoordinate(location))
        return true
    }
    
    fileprivate func rightCursorClicked(at location: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(location) { return false }
        let locationInMask = sceneOverlayView.convert(location, from: wrapper)
        
        var annotatorView: ColorAnnotatorOverlay?
        for view in sceneOverlayView.subviews.reversed() {  // from top to bottom
            if let view = view as? ColorAnnotatorOverlay {
                if view.frame.contains(locationInMask) {
                    annotatorView = view
                    break
                }
            }
        }
        
        if let annotatorView = annotatorView {
            if let coordinate = colorAnnotators.first(where: { $0.pixelView === annotatorView })?.pixelColor.coordinate {
                trackRightCursorClicked(self, at: coordinate)
                return true
            }
        }
        
        trackRightCursorClicked(self, at: PixelCoordinate(location))
        return true
    }
    
    fileprivate func magnifyToolClicked(at location: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            if wrapper.visibleRect.contains(location) {
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(next, centeredAt: location)
                }) { [unowned self] in
                    self.sceneBoundsChanged()
                }
            } else {
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = next
                }) { [unowned self] in
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
            if wrapper.visibleRect.contains(location) {
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(prev, centeredAt: location)
                }) { [unowned self] in
                    self.sceneBoundsChanged()
                }
            } else {
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = prev
                }) { [unowned self] in
                    self.sceneBoundsChanged()
                }
            }
            return true
        }
        return false
    }
    
    override func mouseUp(with event: NSEvent) {
        var handled = false
        if !sceneView.isBeingDragged {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
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
        if !handled {
            super.mouseUp(with: event)
        }
    }
    
    override func rightMouseUp(with event: NSEvent) {
        var handled = false
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        if trackingTool == .cursor {
            handled = rightCursorClicked(at: loc)
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
    
    fileprivate func useCommandModifiedTrackingTool() -> Bool {
        if sceneView.isBeingManipulated { return false }
        if trackingTool == .magnify || trackingTool == .minify || trackingTool == .move {
            trackingTool = .cursor
            return true
        }
        return false
    }
    
    fileprivate func useSelectedTrackingTool() -> Bool {
        trackingTool = selectedTrackingTool
        return true
    }
    
    fileprivate func shortcutMoveCursorOrScene(by direction: NSEvent.SpecialKey, for pixelDistance: CGFloat, from pixelLocation: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(pixelLocation) { return false }
        
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
        
        guard wrapper.visibleRect.contains(targetWrapperPoint) else {
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
            }
            
        }
        
        return false
    }
    
    deinit {
        debugPrint("- [SceneController deinit]")
    }
    
}

extension SceneController: ScreenshotLoader {
    
    func resetController() {
        sceneView.minMagnification = SceneController.minimumZoomingFactor
        sceneView.maxMagnification = SceneController.maximumZoomingFactor
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = false
        sceneView.documentView = SceneImageWrapper()
        
        _ = useSelectedTrackingTool()
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
    
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingObject?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: Any, to rect: PixelRect) {
        trackingObject?.trackAreaChanged(sender, to: rect)
    }
    
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) {
        trackingObject?.trackCursorDragged(sender, to: rect)
    }
    
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingObject?.trackCursorClicked(sender, at: coordinate)
    }
    
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingObject?.trackRightCursorClicked(sender, at: coordinate)
    }
    
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect())
        trackingObject?.trackMagnifyToolDragged(sender, to: rect)
    }
    
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) {
        trackingObject?.trackSceneBoundsChanged(sender, to: rect, of: magnification)
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
    
    @objc fileprivate func sceneDidScrollNotification(_ notification: NSNotification) {
        updateAnnotatorBounds()
        sceneBoundsChanged()
    }
    
    fileprivate func updateFrame(of annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            annotator.view.isSmallArea = true
            let pointInMask = sceneView.convert(annotator.pixelColor.coordinate.toCGPoint().toPixelCenterCGPoint(), from: wrapper)
            annotator.view.frame = CGRect(origin: pointInMask, size: annotator.view.defaultSize).offsetBy(dx: annotator.view.defaultOffset.x, dy: annotator.view.defaultOffset.y)
        }
        else if let annotator = annotator as? AreaAnnotator {
            let rectInMask = sceneView.convert(annotator.pixelArea.rect.toCGRect(), from: wrapper)
            // if smaller than default size
            if rectInMask.width < annotator.view.defaultSize.width || rectInMask.height < annotator.view.defaultSize.height {
                annotator.view.isSmallArea = true
                annotator.view.frame = CGRect(origin: rectInMask.center, size: annotator.view.defaultSize).offsetBy(dx: annotator.view.defaultOffset.x, dy: annotator.view.defaultOffset.y)
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
        updateFrame(of: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
    }
    
    func addAnnotator(for area: PixelArea) {
        let annotator = AreaAnnotator(pixelItem: area.copy() as! PixelArea)
        updateFrame(of: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
    }
    
    func removeAnnotators(for items: [ContentItem]) {
        annotators.filter({ items.contains($0.pixelItem) }).forEach({ $0.view.removeFromSuperview() })
        annotators.removeAll(where: { items.contains($0.pixelItem) })
        debugPrint("remove annotators \(items)")
    }
    
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool) {
        annotators.filter({ $0.isHighlighted }).forEach({ $0.isHighlighted = false })
        annotators.filter({ items.contains($0.pixelItem) }).forEach({
            $0.isHighlighted = true
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
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat) {
        guard magnification >= SceneController.minimumZoomingFactor && magnification <= SceneController.maximumZoomingFactor else { return }
        self.sceneView.magnification = magnification
    }
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        let centerPoint = coordinate.toCGPoint().toPixelCenterCGPoint()
        if !wrapper.visibleRect.contains(centerPoint) {
            var point = sceneView.convert(centerPoint, from: wrapper)
            point.x -= sceneView.bounds.width / 2.0
            point.y -= sceneView.bounds.height / 2.0
            let clipCenterPoint = sceneClipView.convert(point, from: sceneView)
            sceneClipView.animator().setBoundsOrigin(clipCenterPoint)
        }
    }
    
}
