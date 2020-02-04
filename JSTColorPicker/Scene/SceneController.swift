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
    
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        // this method is mentioned by: https://developer.apple.com/documentation/appkit/nsscreen/1388360-devicedescription
        return deviceDescription[NSDeviceDescriptionKey.init(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

class SceneController: NSViewController {
    
    fileprivate static let minimumZoomingFactor: CGFloat = 0.25
    fileprivate static let maximumZoomingFactor: CGFloat = 128.0
    fileprivate static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0
    ]
    fileprivate static let minimumRecognizablePixelWidth: CGFloat = 10.0
    
    weak var trackingObject: SceneTracking?
    internal weak var screenshot: Screenshot?
    internal var annotators: [ColorAnnotator] = []
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
    
    fileprivate func cursorApply(at location: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(location) { return false }
        mouseClicked(self, at: PixelCoordinate(location))
        return true
    }
    
    fileprivate func rightCursorApply(at location: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(location) { return false }
        let locationInMask = sceneOverlayView.convert(location, from: wrapper)
        
        var annotatorView: ColorAnnotatorView?
        for view in sceneOverlayView.subviews.reversed() {  // from top to bottom
            if let view = view as? ColorAnnotatorView {
                if view.frame.contains(locationInMask) {
                    annotatorView = view
                    break
                }
            }
        }
        
        if let annotatorView = annotatorView {
            if let annotator = annotators.first(where: { $0.view === annotatorView }) {
                rightMouseClicked(self, at: annotator.pixelColor.coordinate)
                return true
            }
        }
        
        rightMouseClicked(self, at: PixelCoordinate(location))
        return true
    }
    
    fileprivate func magnifyToolApply(at location: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                self.sceneView.animator().setMagnification(next, centeredAt: location)
            }) {
                self.sceneMagnificationChanged()
            }
            return true
        }
        return false
    }
    
    fileprivate func magnifyToolDraggedApply(in rect: CGRect) -> Bool {
        sceneMagnify(toFit: rect)
        return true
    }
    
    fileprivate func minifyToolApply(at location: CGPoint) -> Bool {
        if !canMinify {
            return false
        }
        if let prev = prevMagnificationFactor {
            NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                self.sceneView.animator().setMagnification(prev, centeredAt: location)
            }) {
                self.sceneMagnificationChanged()
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
                handled = cursorApply(at: loc)
            }
            else if trackingTool == .magnify {
                handled = magnifyToolApply(at: loc)
            }
            else if trackingTool == .minify {
                handled = minifyToolApply(at: loc)
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
            handled = rightCursorApply(at: loc)
        }
        if !handled {
            super.rightMouseUp(with: event)
        }
    }
    
    fileprivate func windowFlagsChanged(with event: NSEvent) -> Bool {
        guard let window = view.window, window.isKeyWindow else { return false }
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
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
    
    fileprivate func shortcutMoveMouse(by direction: NSEvent.SpecialKey, from pixelLocation: CGPoint) -> Bool {
        if !wrapper.visibleRect.contains(pixelLocation) { return false }
        
        var simulatedSize = CGSize.zero
        switch direction {
        case NSEvent.SpecialKey.upArrow:
            simulatedSize.height -= 1.0
        case NSEvent.SpecialKey.downArrow:
            simulatedSize.height += 1.0
        case NSEvent.SpecialKey.leftArrow:
            simulatedSize.width  -= 1.0
        case NSEvent.SpecialKey.rightArrow:
            simulatedSize.width  += 1.0
        default: break
        }
        let convertedSize = wrapper.convert(simulatedSize, to: nil)
        guard abs(convertedSize.width + convertedSize.height) > SceneController.minimumRecognizablePixelWidth else { return false }
        
        var simulatedPoint = pixelLocation.toPixelCenterCGPoint()
        simulatedPoint.x += simulatedSize.width
        simulatedPoint.y += simulatedSize.height
        
        // TODO: make target point visible
        guard wrapper.visibleRect.contains(simulatedPoint) else { return false }
        
        guard let window = wrapper.window else { return false }
        guard let mainScreen = window.screen else { return false }
        guard let displayID = mainScreen.displayID else { return false }
        
        let convertedWindowPoint = wrapper.convert(simulatedPoint, to: nil)
        let convertedScreenPoint = window.convertPoint(toScreen: convertedWindowPoint)
        let screenFrame = mainScreen.frame
        let currentMouseLocationInDisplay = CGPoint(x: convertedScreenPoint.x - screenFrame.origin.x, y: screenFrame.size.height - (convertedScreenPoint.y - screenFrame.origin.y))
        
        CGDisplayHideCursor(kCGNullDirectDisplay)
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayMoveCursorToPoint(displayID, currentMouseLocationInDisplay)
        /* perform your application’s main loop */
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(kCGNullDirectDisplay)
        
        return true
    }
     
    fileprivate func windowKeyDown(with event: NSEvent) -> Bool {
        let loc = wrapper.convert(event.locationInWindow, from: nil)
        if event.modifierFlags.contains(.command) {
            if let specialKey = event.specialKey {
                if specialKey == .upArrow || specialKey == .downArrow || specialKey == .leftArrow || specialKey == .rightArrow {
                    return shortcutMoveMouse(by: specialKey, from: loc)
                }
                else if specialKey == .enter || specialKey == .carriageReturn {
                    return cursorApply(at: loc)
                }
                else if specialKey == .delete {
                    return rightCursorApply(at: loc)
                }
            }
            else if let characters = event.characters {
                if characters.contains("-") {
                    return minifyToolApply(at: loc)
                }
                else if characters.contains("=") {
                    return magnifyToolApply(at: loc)
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
    
    func mousePositionChanged(_ sender: Any, to coordinate: PixelCoordinate) {
        trackingObject?.mousePositionChanged(sender, to: coordinate)
    }
    
    func mouseDraggingAreaChanged(_ sender: Any, to rect: PixelRect) {
        if trackingTool == .magnify {
            _ = magnifyToolDraggedApply(in: rect.toCGRect())
        }
        trackingObject?.mouseDraggingAreaChanged(sender, to: rect)
    }
    
    func mouseClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingObject?.mouseClicked(sender, at: coordinate)
    }
    
    func rightMouseClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        trackingObject?.rightMouseClicked(sender, at: coordinate)
    }
    
    func sceneMagnificationChanged(_ sender: Any, to magnification: CGFloat) {
        trackingObject?.sceneMagnificationChanged(sender, to: magnification)
    }
    
    fileprivate func sceneMagnificationChanged() {
        sceneMagnificationChanged(self, to: sceneView.magnification)
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
        }) {
            self.sceneMagnificationChanged()
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
        sceneMagnificationChanged()
    }
    
    fileprivate func updateAnnotatorBounds() {
        for annotator in annotators {
            let item = annotator.pixelColor
            let pointInImage = item.coordinate.toCGPoint().toPixelCenterCGPoint()
            let pointInMask = sceneView.convert(pointInImage, from: wrapper)
            let maskRect = CGRect(x: pointInMask.x - 15.5, y: pointInMask.y - 16.5, width: 32.0, height: 32.0)
            annotator.view.frame = maskRect
        }
    }
    
    func loadAnnotators(from content: Content) throws {
        addAnnotators(for: content.items)
    }
    
    func addAnnotators(for items: [ContentItem]) {
        items.compactMap({ $0 as? PixelColor }).forEach { (item) in
            if !annotators.contains(where: { $0.pixelColor == item }) {
                let annotator = ColorAnnotator(pixelColor: item)
                annotator.label = "\(item.id)"
                annotators.append(annotator)
                sceneOverlayView.addSubview(annotator.view)
            }
        }
        debugPrint("add annotators \(items)")
        updateAnnotatorBounds()
    }
    
    func removeAnnotators(for items: [ContentItem]) {
        annotators.filter({ items.contains($0.pixelColor) }).forEach { (annotator) in
            annotator.view.removeFromSuperview()
        }
        annotators.removeAll(where: { items.contains($0.pixelColor) })
        debugPrint("remove annotators \(items)")
    }
    
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool) {
        annotators.forEach { (annotator) in
            if items.contains(annotator.pixelColor) {
                annotator.view.removeFromSuperview()
                annotator.isHighlighted = true
                sceneOverlayView.addSubview(annotator.view)
            } else if annotator.isHighlighted {
                annotator.isHighlighted = false
            }
        }
        if scrollTo {  // scroll without changing magnification
            if let coord = annotators.first(where: { items.contains($0.pixelColor) })?.pixelColor.coordinate.toCGPoint() {
                if !wrapper.visibleRect.contains(coord) {  // scroll if not visible
                    var point = sceneView.convert(coord, from: wrapper)
                    point.x -= sceneView.bounds.width / 2.0
                    point.y -= sceneView.bounds.height / 2.0
                    let clipMidPoint = sceneClipView.convert(point, from: sceneView)
                    sceneClipView.animator().setBoundsOrigin(clipMidPoint)
                }
            }
        }
        debugPrint("highlight annotators \(items), scroll = \(scrollTo)")
    }
    
}
