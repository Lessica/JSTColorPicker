//
//  PickerSceneViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import Quartz

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

class SceneController: NSViewController {
    
    fileprivate static let minimumZoomingFactor: CGFloat = 0.25
    fileprivate static let maximumZoomingFactor: CGFloat = 128.0
    fileprivate static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0
    ]
    
    weak var trackingDelegate: SceneTracking?
    @IBOutlet weak var sceneView: SceneScrollView!
    @IBOutlet weak var sceneClipView: SceneClipView!
    
    fileprivate var wrapper: SceneImageWrapper? {
        get {
            if let wrapper = sceneView.documentView as? SceneImageWrapper {
                return wrapper
            }
            return nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            self.flagsChanged(with: event)
            return event
        }
        
        sceneView.backgroundColor = NSColor.init(patternImage: NSImage(named: "JSTBackgroundPattern")!)
        sceneView.contentInsets = NSEdgeInsetsZero
        sceneView.hasVerticalRuler = true
        sceneView.hasHorizontalRuler = true
        sceneView.rulersVisible = true
        sceneView.verticalScrollElasticity = .none
        sceneView.horizontalScrollElasticity = .none
        sceneView.verticalRulerView?.measurementUnits = .points
        sceneView.horizontalRulerView?.measurementUnits = .points
        // `sceneView.documentCursor` is not what we need
        sceneClipView.contentInsets = NSEdgeInsetsMake(240, 240, 240, 240)
        
        resetController()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishRestoringWindowsNotification(_:)), name: NSApplication.didFinishRestoringWindowsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneMagnificationChangedNotification(_:)), name: NSScrollView.didEndLiveMagnifyNotification, object: sceneView)
    }
    
    func resetController() {
        sceneView.minMagnification = SceneController.minimumZoomingFactor
        sceneView.maxMagnification = SceneController.maximumZoomingFactor
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = false
        sceneView.documentView = SceneImageWrapper()
        
        sceneMagnificationChanged(self, toMagnification: sceneView.magnification)
        useSelectedTrackingTool()
    }
    
    func renderImage(_ image: PixelImage) {
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
        
        let wrapper = SceneImageWrapper(frame: initialRect)
        wrapper.trackingDelegate = self
        wrapper.trackingToolDelegate = self
        wrapper.addSubview(imageView)
        
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = true
        sceneView.documentView = wrapper
        
        sceneMagnificationChanged(self, toMagnification: sceneView.magnification)
        useSelectedTrackingTool()
    }
    
    fileprivate var trackingTool: TrackingTool {
        get {
            guard let tool = wrapper?.trackingTool else { return .arrow }
            return tool
        }
        set {
            wrapper?.trackingTool = newValue
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
        
    }
    
    override func mouseUp(with event: NSEvent) {
        guard let documentView = sceneView.documentView else { return }
        let loc = documentView.convert(event.locationInWindow, from: nil)
        if !NSPointInRect(loc, documentView.bounds) { return }
        if trackingTool == .cursor {
            mouseClicked(self, atPoint: loc)
        }
        else if trackingTool == .magnify {
            if !canMagnify {
                return
            }
            if let next = nextMagnificationFactor {
                sceneView.animator().setMagnification(next, centeredAt: loc)
                sceneMagnificationChanged(self, toMagnification: next)
            }
        }
        else if trackingTool == .minify {
            if !canMinify {
                return
            }
            if let prev = prevMagnificationFactor {
                sceneView.animator().setMagnification(prev, centeredAt: loc)
                sceneMagnificationChanged(self, toMagnification: prev)
            }
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard let window = view.window, window.isKeyWindow else { return }
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
        case [.option]:
            useOptionModifiedTrackingTool()
        case [.command]:
            useCommandModifiedTrackingTool()
        default:
            useSelectedTrackingTool()
        }
    }
    
    fileprivate func useOptionModifiedTrackingTool() {
        if trackingTool == .magnify {
            trackingTool = .minify
        }
        else if trackingTool == .minify {
            trackingTool = .magnify
        }
    }
    
    fileprivate func useCommandModifiedTrackingTool() {
        if trackingTool == .magnify || trackingTool == .minify {
            trackingTool = .cursor
        }
    }
    
    fileprivate func useSelectedTrackingTool() {
        trackingTool = selectedTrackingTool
    }
    
    deinit {
        debugPrint("- [SceneController deinit]")
    }
    
}

extension SceneController: SceneTracking {
    
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool {
        let relPoint = sceneView.convert(point, from: wrapper)
        if !NSPointInRect(relPoint, sceneView.bounds) {
            return false
        }
        return trackingDelegate?.mousePositionChanged(sender, toPoint: point) ?? false
    }
    
    func mouseClicked(_ sender: Any, atPoint point: CGPoint) {
        trackingDelegate?.mouseClicked(sender, atPoint: point)
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        trackingDelegate?.sceneMagnificationChanged(sender, toMagnification: magnification)
    }
    
    @objc func didFinishRestoringWindowsNotification(_ notification: NSNotification) {
        sceneMagnificationChangedProgrammatically()
    }
    
    @objc func sceneMagnificationChangedNotification(_ notification: NSNotification) {
        if let scrollView = notification.object as? NSScrollView {
            if scrollView == sceneView {
                trackingDelegate?.sceneMagnificationChanged(self, toMagnification: scrollView.magnification)
            }
        }
    }
    
    fileprivate func sceneMagnificationChangedProgrammatically() {
        trackingDelegate?.sceneMagnificationChanged(self, toMagnification: sceneView.magnification)
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
    
    func fitWindowAction(_ sender: Any?) {
        guard let bounds = wrapper?.bounds else { return }
        NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
            self.sceneView.animator().magnify(toFit: bounds)
        }) {
            self.sceneMagnificationChangedProgrammatically()
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
