//
//  SceneController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneController: NSViewController {
    
    public var wrapperVisibleBounds: CGRect {
        return sceneClipView.bounds.intersection(wrapper.bounds)
    }
    
    public var wrapperMagnification: CGFloat {
        return max(min(sceneView.magnification, SceneController.maximumZoomingFactor), SceneController.minimumZoomingFactor)
    }
    
    weak var trackingDelegate: SceneTracking?
    weak var contentResponder: ContentResponder?
    internal weak var screenshot: Screenshot?
    internal var annotators: [Annotator] = []
    fileprivate var lazyColorAnnotators: [ColorAnnotator] {
        return annotators.lazy.compactMap({ $0 as? ColorAnnotator })
    }
    fileprivate var lazyAreaAnnotators: [AreaAnnotator] {
        return annotators.lazy.compactMap({ $0 as? AreaAnnotator })
    }
    fileprivate var enableForceTouch: Bool {
        get {
            return sceneView.enableForceTouch
        }
        set {
            sceneView.enableForceTouch = newValue
        }
    }
    fileprivate var drawGridsInScene: Bool {
        get {
            return sceneGridView.drawGridsInScene
        }
        set {
            sceneGridView.drawGridsInScene = newValue
        }
    }
    fileprivate var drawRulersInScene: Bool {
        get {
            return sceneView.drawRulersInScene
        }
        set {
            sceneView.drawRulersInScene = newValue
        }
    }
    fileprivate var drawSceneBackground: Bool {
        get {
            return sceneView.drawSceneBackground
        }
        set {
            sceneView.drawSceneBackground = newValue
        }
    }
    fileprivate var usesPredominantAxisScrolling: Bool {
        get {
            return sceneView.usesPredominantAxisScrolling
        }
        set {
            sceneView.usesPredominantAxisScrolling = newValue
        }
    }
    fileprivate var hideGridsWhenResize: Bool = false
    fileprivate var hideAnnotatorsWhenResize: Bool = true
    
    fileprivate static let minimumZoomingFactor: CGFloat = pow(2.0, -2)  // 0.25x
    fileprivate static let maximumZoomingFactor: CGFloat = pow(2.0, 8)   // 256x
    fileprivate static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0, 256.0
    ]
    fileprivate static let minimumRecognizableMagnification: CGFloat = 16.0
    
    @IBOutlet fileprivate weak var sceneClipView: SceneClipView!
    @IBOutlet fileprivate weak var sceneView: SceneScrollView!
    @IBOutlet fileprivate weak var sceneGridView: SceneGridView!
    @IBOutlet fileprivate weak var sceneOverlayView: SceneOverlayView!
    @IBOutlet fileprivate weak var internalSceneEffectView: SceneEffectView!
    @IBOutlet fileprivate weak var sceneGridTopConstraint: NSLayoutConstraint!
    @IBOutlet fileprivate weak var sceneGridLeadingConstraint: NSLayoutConstraint!
    
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
    
    fileprivate var internalSceneTool: SceneTool = .arrow {
        didSet {
            updateAnnotatorEditableStates()
            sceneOverlayView.updateAppearance()
        }
    }
    fileprivate var internalSceneState: SceneState = SceneState()
    
    fileprivate var windowSelectedSceneTool: SceneTool {
        get {
            guard let tool = view.window?.toolbar?.selectedItemIdentifier?.rawValue else { return .arrow }
            return SceneTool(rawValue: tool) ?? .arrow
        }
    }
    
    fileprivate var nextMagnificationFactor: CGFloat? {
        get {
            return SceneController.zoomingFactors.first(where: { $0 > sceneView.magnification })
        }
    }
    
    fileprivate var prevMagnificationFactor: CGFloat? {
        get {
            return SceneController.zoomingFactors.last(where: { $0 < sceneView.magnification })
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
    
    fileprivate var windowActiveNotificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeController()
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            if self.monitorWindowFlagsChanged(with: event) {
                return nil
            }
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] (event) -> NSEvent? in
            guard let self = self else { return event }
            if self.monitorWindowKeyDown(with: event) {
                return nil
            }
            return event
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillStartLiveMagnifyNotification(_:)), name: NSScrollView.willStartLiveMagnifyNotification, object: sceneView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEndLiveMagnifyNotification(_:)), name: NSScrollView.didEndLiveMagnifyNotification, object: sceneView)
        windowActiveNotificationToken = NotificationCenter.default.observe(name: NSWindow.didResignKeyNotification, object: view.window) { [unowned self] notification in
            self.useSelectedSceneTool()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        loadPreferences(nil)
    }
    
    @objc fileprivate func loadPreferences(_ notification: Notification?) {
        // guard (notification?.object as? UserDefaults) == UserDefaults.standard else { return }
        debugPrint("[SceneController loadPreferences(_:)]")
        enableForceTouch = UserDefaults.standard[.enableForceTouch]
        let drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground]
        if self.drawSceneBackground != drawSceneBackground {
            self.drawSceneBackground = drawSceneBackground
        }
        let drawGridsInScene: Bool = UserDefaults.standard[.drawGridsInScene]
        hideGridsWhenResize = UserDefaults.standard[.hideGridsWhenResize]
        hideAnnotatorsWhenResize = UserDefaults.standard[.hideAnnotatorsWhenResize]
        var shouldNotifySceneBoundsChanged = false
        if self.drawGridsInScene != drawGridsInScene {
            self.drawGridsInScene = drawGridsInScene
            shouldNotifySceneBoundsChanged = true
        }
        let drawRulersInScene: Bool = UserDefaults.standard[.drawRulersInScene]
        if self.drawRulersInScene != drawRulersInScene {
            self.drawRulersInScene = drawRulersInScene
            reloadSceneRulerConstraints()
            shouldNotifySceneBoundsChanged = true
        }
        usesPredominantAxisScrolling = UserDefaults.standard[.usesPredominantAxisScrolling]
        if shouldNotifySceneBoundsChanged {
            sceneBoundsChanged()
        }
    }
    
    fileprivate func renderImage(_ image: PixelImage) {
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = true
        
        let imageSize = image.size
        let initialPixelRect = PixelRect(origin: .zero, size: imageSize)
        let wrapper = SceneImageWrapper(pixelBounds: initialPixelRect)
        wrapper.rulerViewClient = self
        wrapper.setImage(image)
        
        sceneView.documentView = wrapper
        sceneView.verticalRulerView?.clientView = wrapper
        sceneView.horizontalRulerView?.clientView = wrapper
        
        useSelectedSceneTool()
    }
    
    fileprivate func applyAnnotateItem(at location: CGPoint) -> Bool {
        if let _ = try? addContentItem(of: PixelCoordinate(location)) {
            return true
        }
        return false
    }
    
    fileprivate func applySelectItem(at location: CGPoint) -> Bool {
        let locationInMask = sceneOverlayView.convert(location, from: wrapper)
        if let annotatorView = sceneOverlayView.frontmostOverlay(at: locationInMask) {
            if annotatorView.isHighlighted { return true }
            if let annotator = annotators.last(where: { $0.view === annotatorView }) {
                if let _ = try? selectContentItem(annotator.pixelItem) {
                    return true
                }
            }
        }
        if let _ = try? selectContentItem(nil) {
            return true
        }
        return false
    }
    
    fileprivate func applyDeleteItem(at location: CGPoint) -> Bool {
        let locationInMask = sceneOverlayView.convert(location, from: wrapper)
        if let annotatorView = sceneOverlayView.frontmostOverlay(at: locationInMask) {
            if let annotator = annotators.last(where: { $0.view === annotatorView }) {
                if let _ = try? deleteContentItem(annotator.pixelItem) {
                    return true
                }
            }
            return false
        }
        if let _ = try? deleteContentItem(of: PixelCoordinate(location)) {
            return true
        }
        return false
    }
    
    fileprivate func applyMagnifyItem(at location: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            if isInscenePixelLocation(location) {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(next, centeredAt: location)
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.sceneBoundsChanged()
                }
            } else {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = next
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.sceneBoundsChanged()
                }
            }
            return true
        }
        return false
    }
    
    fileprivate func applyMinifyItem(at location: CGPoint) -> Bool {
        if !canMinify {
            return false
        }
        if let prev = prevMagnificationFactor {
            if isInscenePixelLocation(location) {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(prev, centeredAt: location)
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.sceneBoundsChanged()
                }
            } else {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = prev
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.sceneBoundsChanged()
                }
            }
            return true
        }
        return false
    }
    
    fileprivate func requiredStageFor(_ tool: SceneTool, type: SceneManipulatingType) -> Int {
        return enableForceTouch ? 1 : 0
    }
    
    override func mouseUp(with event: NSEvent) {
        var handled = false
        if sceneState.type == .leftGeneric {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if isInscenePixelLocation(loc) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.type) {
                    if sceneTool == .magicCursor {
                        handled = applyAnnotateItem(at: loc)
                    }
                    else if sceneTool == .magnifyingGlass {
                        handled = applyMagnifyItem(at: loc)
                    }
                    else if sceneTool == .minifyingGlass {
                        handled = applyMinifyItem(at: loc)
                    }
                    else if sceneTool == .selectionArrow {
                        handled = applySelectItem(at: loc)
                    }
                }
            }
        }
        if !handled {
            super.mouseUp(with: event)
        }
    }
    
    override func rightMouseUp(with event: NSEvent) {
        var handled = false
        if sceneState.type == .rightGeneric {
            let loc = wrapper.convert(event.locationInWindow, from: nil)
            if isInscenePixelLocation(loc) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.type) {
                    if sceneTool == .magicCursor || sceneTool == .selectionArrow {
                        handled = applyDeleteItem(at: loc)
                    }
                }
            }
        }
        if !handled {
            super.rightMouseUp(with: event)
        }
    }
    
    fileprivate func monitorWindowFlagsChanged(with event: NSEvent) -> Bool {
        guard let window = view.window, window.isKeyWindow else { return false }  // important
        var handled = false
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.shift) {
        case [.option]:
            handled = useOptionModifiedSceneTool()
        case [.command]:
            handled = useCommandModifiedSceneTool()
        default:
            handled = useSelectedSceneTool()
        }
        if handled && sceneView.isMouseInside {
            sceneOverlayView.updateAppearance()
        }
        return handled
    }
    
    @discardableResult
    fileprivate func useOptionModifiedSceneTool() -> Bool {
        if sceneState.isManipulating { return false }
        if sceneTool == .magnifyingGlass {
            internalSceneTool = .minifyingGlass
            return true
        }
        else if sceneTool == .minifyingGlass {
            internalSceneTool = .magnifyingGlass
            return true
        }
        return false
    }
    
    @discardableResult
    fileprivate func useCommandModifiedSceneTool() -> Bool {
        if sceneState.isManipulating { return false }
        if sceneTool == .magicCursor {
            internalSceneTool = .selectionArrow
            return true
        }
        else if sceneTool == .magnifyingGlass
            || sceneTool == .minifyingGlass
            || sceneTool == .selectionArrow
            || sceneTool == .movingHand
        {
            internalSceneTool = .magicCursor
            return true
        }
        return false
    }
    
    @discardableResult
    fileprivate func useSelectedSceneTool() -> Bool {
        internalSceneTool = windowSelectedSceneTool
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
        
        guard wrapperMagnification >= SceneController.minimumRecognizableMagnification else { return false }
        
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
        
        trackColorChanged(sceneView, at: PixelCoordinate(targetWrapperPoint))
        return true
    }
    
    @discardableResult
    fileprivate func shortcutCopyPixelColor(at pixelLocation: CGPoint) -> Bool {
        guard let screenshot = screenshot else { return false }
        guard isInscenePixelLocation(pixelLocation) else { return false }
        try? screenshot.export.copyPixelColor(at: PixelCoordinate(pixelLocation))
        return true
    }
     
    fileprivate func monitorWindowKeyDown(with event: NSEvent) -> Bool {
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
                    return applyAnnotateItem(at: loc)
                }
                else if specialKey == .delete {
                    return applyDeleteItem(at: loc)
                }
            }
            else if let characters = event.characters {
                if characters.contains("-") {
                    return applyMinifyItem(at: loc)
                }
                else if characters.contains("=") {
                    return applyMagnifyItem(at: loc)
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
        
        let wrapper = SceneImageWrapper(pixelBounds: .zero)
        wrapper.rulerViewClient = self
        sceneView.documentView = wrapper
        sceneView.verticalRulerView?.clientView = wrapper
        sceneView.horizontalRulerView?.clientView = wrapper
        
        // `sceneView.documentCursor` is not what we need, see `SceneScrollView` for a more accurate implementation of cursor appearance
        sceneClipView.contentInsets = NSEdgeInsetsMake(240, 240, 240, 240)
        reloadSceneRulerConstraints()
        
        sceneView.trackingDelegate = self
        sceneView.sceneToolDataSource = self
        sceneView.sceneStateDataSource = self
        sceneView.sceneActionEffectViewDataSource = self
        sceneView.sceneEventObservers = [
            SceneEventObserver(self, types: [.mouseUp, .rightMouseUp], order: [.before]),
            SceneEventObserver(sceneOverlayView, types: .all, order: [.after])
        ]
        
        sceneOverlayView.sceneToolDataSource = self
        sceneOverlayView.sceneStateDataSource = self
        sceneOverlayView.annotatorDataSource = self
        
        useSelectedSceneTool()
    }
    
    fileprivate func reloadSceneRulerConstraints() {
        sceneGridTopConstraint.constant = sceneView.alternativeBoundsOrigin.y
        sceneGridLeadingConstraint.constant = sceneView.alternativeBoundsOrigin.x
        updateAnnotatorFrames()
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
    
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        if !sceneOverlayView.isHidden {
            updateAnnotatorFrames()
        }
        sceneGridView.trackSceneBoundsChanged(sender, to: rect, of: magnification)
        trackingDelegate?.trackSceneBoundsChanged(sender, to: rect, of: magnification)
    }
    
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        trackingDelegate?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: SceneScrollView?, to rect: PixelRect) {
        trackingDelegate?.trackAreaChanged(sender, to: rect)
    }
    
    func trackMagnifyingGlassDragged(_ sender: SceneScrollView?, to rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect())
    }
    
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to rect: PixelRect) {
        if let overlay = sceneState.manipulatingOverlay as? AreaAnnotatorOverlay {
            guard let annotator = lazyAreaAnnotators.last(where: { $0.pixelView === overlay }) else { return }
            guard annotator.pixelArea.rect != rect else { return }
            guard let item = annotator.pixelItem.copy() as? PixelArea else { return }
            if let _ = try? updateContentItem(item, to: rect) {
                // do nothing
                return
            }
        }
        else {
            _ = try? addContentItem(of: rect)
        }
    }
    
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to coordinate: PixelCoordinate) {
        if let overlay = sceneState.manipulatingOverlay as? ColorAnnotatorOverlay {
            guard let annotator = lazyColorAnnotators.last(where: { $0.pixelView === overlay }) else { return }
            guard annotator.pixelColor.coordinate != coordinate else { return }
            guard let item = annotator.pixelItem.copy() as? PixelColor else { return }
            if let _ = try? updateContentItem(item, to: coordinate) {
                // do nothing
                return
            }
        }
    }
    
    fileprivate func sceneBoundsChanged() {
        trackSceneBoundsChanged(sceneView, to: wrapperVisibleBounds, of: wrapperMagnification)
    }
    
}

extension SceneController: SceneToolDataSource {
    
    internal var sceneTool: SceneTool {
        get {
            return internalSceneTool
        }
    }
    
    func sceneToolEnabled(_ sender: Any) -> Bool {
        if sceneTool == .magnifyingGlass {
            return canMagnify
        }
        else if sceneTool == .minifyingGlass {
            return canMinify
        }
        return true
    }
    
}

extension SceneController: SceneStateDataSource {
    
    internal var sceneState: SceneState {
        get {
            return internalSceneState
        }
        set {
            internalSceneState = newValue
        }
    }
    
    internal var editingAnnotatorOverlayAtBeginLocation: EditableOverlay? {
        get {
            let loc = sceneOverlayView.convert(sceneState.beginLocation, from: sceneView)
            guard let overlay = sceneOverlayView.frontmostOverlay(at: loc) else { return nil }
            overlay.setEditing(at: sceneOverlayView.convert(loc, to: overlay))
            return overlay
        }
    }
    
}

extension SceneController: SceneEffectViewDataSource {
    
    var sceneEffectView: SceneEffectView {
        return internalSceneEffectView
    }
    
}

extension SceneController: AnnotatorDataSource {
    
    @objc fileprivate func sceneWillStartLiveMagnifyNotification(_ notification: NSNotification) {
        hideSceneOverlays()
    }
    
    @objc fileprivate func sceneDidEndLiveMagnifyNotification(_ notification: NSNotification) {
        showSceneOverlays()
    }
    
    fileprivate func hideSceneOverlays() {
        if hideGridsWhenResize {
            sceneGridView.isHidden = true
        }
        if hideAnnotatorsWhenResize {
            sceneOverlayView.isHidden = true
        }
    }
    
    fileprivate func showSceneOverlays() {
        sceneGridView.isHidden = false
        sceneOverlayView.isHidden = false
        updateAnnotatorFrames()
    }
    
    fileprivate func updateFrame(of annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            annotator.isFixedAnnotator = true
            let pointInMask =
                sceneView
                    .convert(annotator.pixelColor.coordinate.toCGPoint().toPixelCenterCGPoint(), from: wrapper)
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
            annotator.view.frame = 
                CGRect(origin: pointInMask, size: AnnotatorOverlay.fixedOverlaySize)
                    .offsetBy(AnnotatorOverlay.fixedOverlayOffset)
                    .inset(by: annotator.view.outerInsets)
        }
        else if let annotator = annotator as? AreaAnnotator {
            let rectInMask =
                sceneView
                    .convert(annotator.pixelArea.rect.toCGRect(), from: wrapper)
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
            // if smaller than default size
            if rectInMask.size < AnnotatorOverlay.fixedOverlaySize {
                annotator.isFixedAnnotator = true
                annotator.view.frame =
                    CGRect(origin: rectInMask.center, size: AnnotatorOverlay.fixedOverlaySize)
                        .offsetBy(AnnotatorOverlay.fixedOverlayOffset)
                        .inset(by: annotator.view.outerInsets)
            } else {
                annotator.isFixedAnnotator = false
                annotator.view.frame =
                    rectInMask
                        .inset(by: annotator.view.outerInsets)
            }
        }
    }
    
    fileprivate func updateAnnotatorFrames() {
        annotators.forEach({ updateFrame(of: $0) })
    }
    
    fileprivate func updateEditableStates(of annotator: Annotator) {
        let editable = internalSceneTool == .selectionArrow
        if annotator.isEditable != editable { annotator.isEditable = editable }
        updateFrame(of: annotator)
    }
    
    fileprivate func updateAnnotatorEditableStates() {
        let editable = internalSceneTool == .selectionArrow
        annotators.lazy
            .filter({ $0.isEditable != editable })
            .forEach({
                $0.isEditable = editable
            })
        updateAnnotatorFrames()
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
            if let color = item as? PixelColor { addAnnotator(for: color) }
            else if let area = item as? PixelArea { addAnnotator(for: area) }
        }
        debugPrint("add annotators \(items)")
    }
    
    func addAnnotator(for color: PixelColor) {
        let annotator = ColorAnnotator(pixelItem: color.copy() as! PixelColor)
        loadRulerMarkers(for: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
        updateEditableStates(of: annotator)
    }
    
    func addAnnotator(for area: PixelArea) {
        let annotator = AreaAnnotator(pixelItem: area.copy() as! PixelArea)
        loadRulerMarkers(for: annotator)
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelView)
        updateEditableStates(of: annotator)
    }
    
    func updateAnnotator(for items: [ContentItem]) {
        let itemIDs = items.compactMap({ $0.id })
        let itemsToRemove = annotators
            .compactMap({ $0.pixelItem })
            .filter({ itemIDs.contains($0.id) })
        removeAnnotators(for: itemsToRemove)
        addAnnotators(for: items)
    }
    
    func removeAnnotators(for items: [ContentItem]) {
        annotators.lazy
            .filter({ items.contains($0.pixelItem) })
            .forEach({
                hideRulerMarkers(for: $0)
                $0.view.removeFromSuperview()
            })
        annotators.removeAll(where: { items.contains($0.pixelItem) })
        debugPrint("remove annotators \(items)")
    }
    
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool) {
        annotators
            .forEach({ (annotator) in
                if items.contains(annotator.pixelItem) {
                    if !annotator.isHighlighted {
                        annotator.isHighlighted = true
                        showRulerMarkers(for: annotator)
                        annotator.view.bringToFront()
                    }
                }
                else if annotator.isHighlighted {
                    annotator.isHighlighted = false
                    hideRulerMarkers(for: annotator)
                    annotator.setNeedsDisplay()
                }
            })
        if scrollTo {  // scroll without changing magnification
            let item = annotators.last(where: { items.contains($0.pixelItem) })?.pixelItem
            if let color = item as? PixelColor { previewAction(self, centeredAt: color.coordinate) }
            else if let area = item as? PixelArea { previewAction(self, centeredAt: area.rect.origin) }
        }
        debugPrint("highlight annotators \(items), scroll = \(scrollTo)")
    }
    
}

extension SceneController: ToolbarResponder {
    
    func useAnnotateItemAction(_ sender: Any?) {
        internalSceneTool = .magicCursor
    }
    
    func useMagnifyItemAction(_ sender: Any?) {
        internalSceneTool = .magnifyingGlass
    }
    
    func useMinifyItemAction(_ sender: Any?) {
        internalSceneTool = .minifyingGlass
    }
    
    func useSelectItemAction(_ sender: Any?) {
        internalSceneTool = .selectionArrow
    }
    
    func useMoveItemAction(_ sender: Any?) {
        internalSceneTool = .movingHand
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
    
    func selectContentItem(_ item: ContentItem?) throws -> ContentItem? {
        return try contentResponder?.selectContentItem(item)
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentResponder?.deleteContentItem(of: coordinate)
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentResponder?.deleteContentItem(item)
    }
    
}

extension SceneController: PreviewResponder {
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) {
        guard magnification >= SceneController.minimumZoomingFactor && magnification <= SceneController.maximumZoomingFactor else { return }
        if sceneOverlayView.isHidden != isChanging {
            if isChanging {
                hideSceneOverlays()
            } else {
                showSceneOverlays()
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

extension SceneController: PixelMatchResponder {
    
    fileprivate var isInComparisonMode: Bool {
        return wrapper.isInComparisonMode
    }
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: (Bool) -> Void) {
        wrapper.setMaskImage(maskImage)
    }
    
    func endPixelMatchComparison() {
        wrapper.setMaskImage(nil)
    }
    
}
