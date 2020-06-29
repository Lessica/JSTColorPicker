//
//  SceneController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SceneController: NSViewController {
    
    public weak var contentDelegate: ContentDelegate!
    public weak var trackingDelegate: SceneTracking!
    public weak var tagListSource: TagListSource!
    
    internal weak var screenshot: Screenshot?
    internal var annotators: [Annotator] = []
    
    private var lazyColorAnnotators: [ColorAnnotator] { annotators.lazy.compactMap({ $0 as? ColorAnnotator }) }
    private var lazyAreaAnnotators: [AreaAnnotator] { annotators.lazy.compactMap({ $0 as? AreaAnnotator }) }
    
    private var enableForceTouch: Bool {
        get {
            return sceneView.enableForceTouch
        }
        set {
            sceneView.enableForceTouch = newValue
        }
    }
    private var drawGridsInScene: Bool {
        get {
            return sceneGridView.drawGridsInScene
        }
        set {
            sceneGridView.drawGridsInScene = newValue
        }
    }
    private var drawRulersInScene: Bool {
        get {
            return sceneView.drawRulersInScene
        }
        set {
            sceneView.drawRulersInScene = newValue
        }
    }
    private var drawSceneBackground: Bool {
        get {
            return sceneView.drawSceneBackground
        }
        set {
            sceneView.drawSceneBackground = newValue
        }
    }
    private var usesPredominantAxisScrolling: Bool {
        get {
            return sceneView.usesPredominantAxisScrolling
        }
        set {
            sceneView.usesPredominantAxisScrolling = newValue
        }
    }
    private var hideGridsWhenResize: Bool = false
    private var hideAnnotatorsWhenResize: Bool = true
    
    private static let minimumZoomingFactor: CGFloat = pow(2.0, -2)  // 0.25x
    private static let maximumZoomingFactor: CGFloat = pow(2.0, 8)   // 256x
    private static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0, 256.0
    ]
    private static let minimumRecognizableMagnification: CGFloat = 16.0
    
    @IBOutlet private weak var sceneClipView: SceneClipView!
    @IBOutlet private weak var sceneView: SceneScrollView!
    @IBOutlet private weak var sceneGridView: SceneGridView!
    @IBOutlet private weak var sceneOverlayView: SceneOverlayView!
    @IBOutlet private weak var internalSceneEffectView: SceneEffectView!
    @IBOutlet private weak var sceneGridTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var sceneGridLeadingConstraint: NSLayoutConstraint!
    
    private var horizontalRulerView: RulerView { sceneView.horizontalRulerView as! RulerView }
    private var verticalRulerView: RulerView { sceneView.verticalRulerView as! RulerView }
    
    private var wrapper: SceneImageWrapper { sceneView.documentView as! SceneImageWrapper }
    public var wrapperBounds: CGRect { wrapper.bounds }
    public var wrapperVisibleRect: CGRect { wrapper.visibleRect }
    public var wrapperMangnification: CGFloat { sceneView.magnification }
    public var wrapperRestrictedRect: CGRect { wrapperVisibleRect.intersection(wrapperBounds) }
    public var wrapperRestrictedMagnification: CGFloat { max(min(wrapperMangnification, SceneController.maximumZoomingFactor), SceneController.minimumZoomingFactor) }
    
    private func isVisibleLocation(_ location: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(location)
    }
    private func isVisibleWrapperLocation(_ locInWrapper: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(sceneView.convert(locInWrapper, from: wrapper))
            && wrapperVisibleRect.contains(locInWrapper)
    }
    
    private var internalSceneTool: SceneTool = .arrow {
        didSet {
            updateAnnotatorEditableStates()
            sceneOverlayView.updateAppearance()
        }
    }
    private var internalSceneState: SceneState = SceneState()
    
    private var windowSelectedSceneTool: SceneTool {
        get {
            guard let tool = view.window?.toolbar?.selectedItemIdentifier?.rawValue else { return .arrow }
            return SceneTool(rawValue: tool) ?? .arrow
        }
    }
    
    private var nextMagnificationFactor: CGFloat? { SceneController.zoomingFactors.first(where: { $0 > sceneView.magnification }) }
    private var prevMagnificationFactor: CGFloat? { SceneController.zoomingFactors.last(where: { $0 < sceneView.magnification }) }
    
    private var canMagnify: Bool {
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
    
    private var canMinify: Bool {
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
    
    private var windowActiveNotificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.minMagnification = SceneController.minimumZoomingFactor
        sceneView.maxMagnification = SceneController.maximumZoomingFactor
        sceneView.magnification = SceneController.minimumZoomingFactor
        sceneView.allowsMagnification = false
        
        let wrapper = SceneImageWrapper(pixelBounds: .zero)
        wrapper.rulerViewClient = self
        sceneView.documentView                    = wrapper
        sceneView.verticalRulerView?.clientView   = wrapper
        sceneView.horizontalRulerView?.clientView = wrapper
        
        // `sceneView.documentCursor` is not what we need, see `SceneScrollView` for a more accurate implementation of cursor appearance
        sceneClipView.contentInsets = NSEdgeInsetsMake(240, 240, 240, 240)
        reloadSceneRulerConstraints()
        
        sceneView.sceneEventObservers = Set([
            SceneEventObserver(self, types: [.mouseUp, .rightMouseUp], order: [.before]),
            SceneEventObserver(sceneOverlayView, types: .all, order: [.after])
        ])
        
        sceneView.trackingDelegate                 = self
        sceneView.sceneToolSource                  = self
        sceneView.sceneStateSource                 = self
        sceneView.sceneActionEffectViewSource      = self
        sceneOverlayView.sceneToolSource           = self
        sceneOverlayView.sceneStateSource          = self
        sceneOverlayView.sceneTagsEffectViewSource = self
        sceneOverlayView.annotatorSource           = self
        sceneOverlayView.contentDelegate           = self
        
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
        useSelectedSceneTool()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidLoadNotification(_:)), name: NSNotification.Name.NSManagedObjectContextDidLoad, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(managedTagsDidChangeNotification(_:)), name: NSNotification.Name.NSManagedObjectContextObjectsDidChange, object: nil)
        applyPreferences(nil)
    }
    
    @objc private func applyPreferences(_ notification: Notification?) {
        
        enableForceTouch = UserDefaults.standard[.enableForceTouch]
        hideGridsWhenResize = UserDefaults.standard[.hideGridsWhenResize]
        hideAnnotatorsWhenResize = UserDefaults.standard[.hideAnnotatorsWhenResize]
        usesPredominantAxisScrolling = UserDefaults.standard[.usesPredominantAxisScrolling]
        
        let drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground]
        if self.drawSceneBackground != drawSceneBackground {
            self.drawSceneBackground = drawSceneBackground
        }
        
        var shouldNotifySceneBoundsChanged = false
        
        let drawGridsInScene: Bool = UserDefaults.standard[.drawGridsInScene]
        if self.drawGridsInScene != drawGridsInScene {
            self.drawGridsInScene = drawGridsInScene
            shouldNotifySceneBoundsChanged = true
        }
        
        let hideGridsInScene = !drawGridsInScene
        if sceneGridView.isHidden != hideGridsInScene {
            sceneGridView.isHidden = hideGridsInScene
        }
        
        let drawRulersInScene: Bool = UserDefaults.standard[.drawRulersInScene]
        if self.drawRulersInScene != drawRulersInScene {
            self.drawRulersInScene = drawRulersInScene
            reloadSceneRulerConstraints()
            shouldNotifySceneBoundsChanged = true
        }
        
        if notification != nil && shouldNotifySceneBoundsChanged {
            notifyVisibleRectChanged()
        }
        
    }
    
    private func renderImage(_ image: PixelImage) {
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
    
    private func applyAnnotateItem(at locInWrapper: CGPoint) -> Bool {
        guard isVisibleWrapperLocation(locInWrapper) else { return false }
        if let _ = try? addContentItem(of: PixelCoordinate(locInWrapper)) {
            return true
        }
        return false
    }
    
    private func applySelectItem(at location: CGPoint, byThroughoutHit throughout: Bool, byExtendingSelection extend: Bool) -> Bool {
        let locInMask = sceneOverlayView.convert(location, from: sceneView)
        if throughout {  // shift pressed
            let annotatorOverlays = sceneOverlayView.overlays(at: locInMask)
            if annotatorOverlays.count > 0 {
                let annotatorOverlaysSet = Set(annotatorOverlays.filter({ !$0.isSelected }))  // is it safe to identify a view by its hash?
                let contentItems = annotators
                    .filter({ annotatorOverlaysSet.contains($0.overlay) })
                    .compactMap({ $0.contentItem })
                if let _ = try? selectContentItems(contentItems, byExtendingSelection: true) {
                    return true
                }
            } else {
                deselectAllContentItems()
            }
        } else {
            if let annotatorOverlay = sceneOverlayView.frontmostOverlay(at: locInMask) {
                guard let annotator = annotators.last(where: { $0.overlay === annotatorOverlay }) else { return false }
                if annotatorOverlay.isSelected && extend {
                    if let _ = try? deselectContentItem(annotator.contentItem) {
                        return true
                    }
                } else {
                    if let _ = try? selectContentItem(annotator.contentItem, byExtendingSelection: extend) {
                        return true
                    }
                }
            } else {
                deselectAllContentItems()
            }
        }
        return false
    }
    
    private func applyDeleteItem(at locInWrapper: CGPoint) -> Bool {
        let locInMask = sceneOverlayView.convert(locInWrapper, from: wrapper)
        if let annotatorView = sceneOverlayView.frontmostOverlay(at: locInMask) {
            if let annotator = annotators.last(where: { $0.overlay === annotatorView }) {
                if let _ = try? deleteContentItem(annotator.contentItem) {
                    return true
                }
            }
            return false
        }
        if let _ = try? deleteContentItem(of: PixelCoordinate(locInWrapper)) {
            return true
        }
        return false
    }
    
    private func applyMagnifyItem(at locInWrapper: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            if isVisibleWrapperLocation(locInWrapper) {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(next, centeredAt: locInWrapper)
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.notifyVisibleRectChanged()
                }
            } else {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = next
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.notifyVisibleRectChanged()
                }
            }
            return true
        }
        return false
    }
    
    private func applyMinifyItem(at locInWrapper: CGPoint) -> Bool {
        if !canMinify {
            return false
        }
        if let prev = prevMagnificationFactor {
            if isVisibleWrapperLocation(locInWrapper) {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().setMagnification(prev, centeredAt: locInWrapper)
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.notifyVisibleRectChanged()
                }
            } else {
                self.hideSceneOverlays()
                NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
                    self.sceneView.animator().magnification = prev
                }) { [unowned self] in
                    self.showSceneOverlays()
                    self.notifyVisibleRectChanged()
                }
            }
            return true
        }
        return false
    }
    
    private func shortcutAnnotatorSwitching(at locInWrapper: CGPoint, byForwardingSelection forward: Bool) -> Bool {
        let locInMask = sceneOverlayView.convert(locInWrapper, from: wrapper)
        let annotatorOverlays = sceneOverlayView.overlays(at: locInMask, bySizeReordering: true)
        guard annotatorOverlays.count > 1 else { return false }
        
        var selectedOverlayIndex: Int?
        for (overlayIndex, annotatorOverlay) in annotatorOverlays.enumerated() {
            if annotatorOverlay.isSelected {
                if selectedOverlayIndex == nil {
                    selectedOverlayIndex = overlayIndex
                } else {
                    // only one selected overlay accepted
                    return false
                }
            }
        }
        
        guard let firstIndex = selectedOverlayIndex else         { return false }
        
        var nextIndex: Int!
        if firstIndex == 0 && forward {
            nextIndex = annotatorOverlays.count - 1
        } else if firstIndex == annotatorOverlays.count - 1 && !forward {
            nextIndex = 0
        } else {
            nextIndex = forward ? firstIndex - 1 : firstIndex + 1
        }
        
        if let nextAnnotator = annotators.first(where: { $0.overlay == annotatorOverlays[nextIndex] }) {
            if let _ = try? selectContentItems([nextAnnotator.contentItem], byExtendingSelection: false) {
                return true
            }
        }
        
        return false
    }
    
    private func requiredStageFor(_ tool: SceneTool, type: SceneManipulatingType) -> Int {
        return enableForceTouch ? 1 : 0
    }
    
    override func mouseUp(with event: NSEvent) {
        var handled = false
        if sceneState.type == .leftGeneric {
            let location = sceneView.convert(event.locationInWindow, from: nil)
            if isVisibleLocation(location) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.type) {
                    if sceneTool == .selectionArrow {
                        let modifierFlags = event.modifierFlags
                            .intersection(.deviceIndependentFlagsMask)
                        let commandPressed = modifierFlags.contains(.command)
                        let shiftPressed   = modifierFlags.contains(.shift)
                        handled = applySelectItem(at: location, byThroughoutHit: shiftPressed, byExtendingSelection: commandPressed)
                    } else {
                        let locInWrapper = wrapper.convert(event.locationInWindow, from: nil)
                        if sceneTool == .magicCursor {
                            handled = applyAnnotateItem(at: locInWrapper)
                        }
                        else if sceneTool == .magnifyingGlass {
                            handled = applyMagnifyItem(at: locInWrapper)
                        }
                        else if sceneTool == .minifyingGlass {
                            handled = applyMinifyItem(at: locInWrapper)
                        }
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
            let locInWrapper = wrapper.convert(event.locationInWindow, from: nil)
            if isVisibleWrapperLocation(locInWrapper) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.type) {
                    if sceneTool == .magicCursor || sceneTool == .selectionArrow {
                        handled = applyDeleteItem(at: locInWrapper)
                    }
                }
            }
        }
        if !handled {
            super.rightMouseUp(with: event)
        }
    }
    
    @discardableResult
    private func monitorWindowFlagsChanged(with event: NSEvent?, forceReset: Bool = false) -> Bool {
        guard let window = view.window, window.isKeyWindow else { return false }  // important
        var handled = false
        let modifierFlags = event?.modifierFlags ?? NSEvent.modifierFlags
        switch modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .command])
        {
        case [.option]:
            handled = useOptionModifiedSceneTool(forceReset)
        case [.control]:
            handled = useCommandModifiedSceneTool(forceReset)
        default:
            handled = useSelectedSceneTool(forceReset)
        }
        if handled && sceneView.isMouseInside {
            sceneOverlayView.updateAppearance()
        }
        return handled
    }
    
    @discardableResult
    private func useOptionModifiedSceneTool(_ forceReset: Bool = false) -> Bool {
        guard forceReset || !sceneState.isManipulating else { return false }
        let selectedSceneTool = windowSelectedSceneTool
        if selectedSceneTool == .magnifyingGlass {
            internalSceneTool = .minifyingGlass
            return true
        }
        else if selectedSceneTool == .minifyingGlass {
            internalSceneTool = .magnifyingGlass
            return true
        }
        return false
    }
    
    @discardableResult
    private func useCommandModifiedSceneTool(_ forceReset: Bool = false) -> Bool {
        guard forceReset || !sceneState.isManipulating else { return false }
        let selectedSceneTool = windowSelectedSceneTool
        if selectedSceneTool == .magicCursor {
            internalSceneTool = .selectionArrow
            return true
        }
        else if selectedSceneTool == .magnifyingGlass
            || selectedSceneTool == .minifyingGlass
            || selectedSceneTool == .selectionArrow
            || selectedSceneTool == .movingHand
        {
            internalSceneTool = .magicCursor
            return true
        }
        return false
    }
    
    @discardableResult
    private func useSelectedSceneTool(_ forceReset: Bool = true) -> Bool {
        internalSceneTool = windowSelectedSceneTool
        return true
    }
    
    @discardableResult
    private func shortcutMoveCursorOrScene(by direction: NSEvent.SpecialKey, for pixelDistance: CGFloat, from locInWrapper: CGPoint) -> Bool {
        guard isVisibleWrapperLocation(locInWrapper) else { return false }
        
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
        
        guard wrapperRestrictedMagnification >= SceneController.minimumRecognizableMagnification else { return false }
        
        var toWrapperPoint = locInWrapper.toPixelCenterCGPoint()
        toWrapperPoint.x += wrapperDelta.width
        toWrapperPoint.y += wrapperDelta.height
        
        guard wrapperBounds.contains(toWrapperPoint) else { return false }
        
        guard isVisibleWrapperLocation(toWrapperPoint) else {
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
        
        let windowPoint = wrapper.convert(toWrapperPoint, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        let screenFrame = mainScreen.frame
        let targetDisplayMousePosition = CGPoint(x: screenPoint.x - screenFrame.origin.x, y: screenFrame.size.height - (screenPoint.y - screenFrame.origin.y))
        
        CGDisplayHideCursor(kCGNullDirectDisplay)
        CGAssociateMouseAndMouseCursorPosition(0)
        CGDisplayMoveCursorToPoint(displayID, targetDisplayMousePosition)
        /* perform your application’s main loop */
        CGAssociateMouseAndMouseCursorPosition(1)
        CGDisplayShowCursor(kCGNullDirectDisplay)
        
        trackColorChanged(sceneView, at: PixelCoordinate(toWrapperPoint))
        return true
    }
    
    @discardableResult
    private func shortcutCopyPixelColor(at locInWrapper: CGPoint) -> Bool {
        guard let screenshot = screenshot else { return false }
        guard isVisibleWrapperLocation(locInWrapper) else { return false }
        try? screenshot.export.copyPixelColor(at: PixelCoordinate(locInWrapper))
        return true
    }
    
    @discardableResult
    private func monitorWindowKeyDown(with event: NSEvent?) -> Bool {
        guard let event = event else { return false }
        guard let window = view.window, window.isKeyWindow else { return false }  // important
        let locInWrapper = wrapper.convert(event.locationInWindow, from: nil)
        
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
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
                    return shortcutMoveCursorOrScene(by: specialKey, for: distance, from: locInWrapper)
                }
                else if isVisibleWrapperLocation(locInWrapper) {
                    if specialKey == .enter || specialKey == .carriageReturn {
                        return applyAnnotateItem(at: locInWrapper)
                    }
                    else if specialKey == .delete {
                        return applyDeleteItem(at: locInWrapper)
                    }
                }
            }
            else if let characters = event.characters {
                if characters.contains("-") {
                    return applyMinifyItem(at: locInWrapper)
                }
                else if characters.contains("=") {
                    return applyMagnifyItem(at: locInWrapper)
                }
                else if characters.contains("`") {
                    return shortcutCopyPixelColor(at: locInWrapper)
                }
                else if characters.contains("[") {
                    return shortcutAnnotatorSwitching(at: locInWrapper, byForwardingSelection: true)
                }
                else if characters.contains("]") {
                    return shortcutAnnotatorSwitching(at: locInWrapper, byForwardingSelection: false)
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
    
    private func reloadSceneRulerConstraints() {
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
    
    func trackVisibleRectChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        if !sceneOverlayView.isHidden {
            updateAnnotatorFrames()
        }
        sceneGridView.trackVisibleRectChanged(sender, to: rect, of: magnification)
        trackingDelegate.trackVisibleRectChanged(sender, to: rect, of: magnification)
    }
    
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        trackingDelegate.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: SceneScrollView?, to rect: PixelRect) {
        trackingDelegate.trackAreaChanged(sender, to: rect)
    }
    
    func trackMagnifyingGlassDragged(_ sender: SceneScrollView?, to rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect(), adjustBorder: true)
    }
    
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to rect: PixelRect) {
        if let overlay = sceneState.manipulatingOverlay as? AreaAnnotatorOverlay {
            guard let annotator = lazyAreaAnnotators.last(where: { $0.pixelOverlay === overlay }) else { return }
            guard annotator.pixelArea.rect != rect else { return }
            guard let item = annotator.contentItem.copy() as? PixelArea else { return }
            _ = try? updateContentItem(item, to: rect)
        }
        else {
            _ = try? addContentItem(of: rect)
        }
    }
    
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to coordinate: PixelCoordinate) {
        if let overlay = sceneState.manipulatingOverlay as? ColorAnnotatorOverlay {
            guard let annotator = lazyColorAnnotators.last(where: { $0.pixelOverlay === overlay }) else { return }
            guard annotator.pixelColor.coordinate != coordinate else { return }
            guard let item = annotator.contentItem.copy() as? PixelColor else { return }
            _ = try? updateContentItem(item, to: coordinate)
        }
    }
    
    private func notifyVisibleRectChanged() {
        trackVisibleRectChanged(sceneView, to: wrapperRestrictedRect, of: wrapperRestrictedMagnification)
    }
    
}

extension SceneController: SceneToolSource {
    
    internal var sceneTool: SceneTool {
        get {
            return internalSceneTool
        }
    }
    
    var sceneToolEnabled: Bool {
        if sceneTool == .magnifyingGlass {
            return canMagnify
        }
        else if sceneTool == .minifyingGlass {
            return canMinify
        }
        return screenshot != nil
    }
    
    func resetSceneTool() {
        monitorWindowFlagsChanged(with: nil, forceReset: true)
    }
    
}

extension SceneController: SceneStateSource {
    
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
            let locInMask = sceneOverlayView.convert(sceneState.beginLocation, from: sceneView)
            guard let overlay = sceneOverlayView.frontmostOverlay(at: locInMask) else { return nil }
            overlay.setEditing(at: sceneOverlayView.convert(locInMask, to: overlay))
            return overlay
        }
    }
    
}

extension SceneController: SceneEffectViewSource {
    
    var sceneEffectView: SceneEffectView {
        return internalSceneEffectView
    }
    
}

extension SceneController: AnnotatorSource {
    
    @objc private func sceneWillStartLiveMagnifyNotification(_ notification: NSNotification) {
        hideSceneOverlays()
    }
    
    @objc private func sceneDidEndLiveMagnifyNotification(_ notification: NSNotification) {
        showSceneOverlays()
    }
    
    private func hideSceneOverlays() {
        if hideGridsWhenResize && !sceneGridView.isHidden {
            sceneGridView.isHidden = true
        }
        if hideAnnotatorsWhenResize && !sceneOverlayView.isHidden {
            sceneOverlayView.isHidden = true
        }
    }
    
    private func showSceneOverlays() {
        if drawGridsInScene && sceneGridView.isHidden {
            sceneGridView.isHidden = false
        }
        if sceneOverlayView.isHidden {
            sceneOverlayView.isHidden = false
        }
        updateAnnotatorFrames()
    }
    
    private func updateFrame(of annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            annotator.isFixedAnnotator = true
            let pointInMask =
                sceneView
                    .convert(annotator.pixelColor.coordinate.toCGPoint().toPixelCenterCGPoint(), from: wrapper)
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
            annotator.overlay.frame = 
                CGRect(origin: pointInMask, size: AnnotatorOverlay.fixedOverlaySize)
                    .offsetBy(AnnotatorOverlay.fixedOverlayOffset)
                    .inset(by: annotator.overlay.outerInsets)
        }
        else if let annotator = annotator as? AreaAnnotator {
            let rectInMask =
                sceneView
                    .convert(annotator.pixelArea.rect.toCGRect(), from: wrapper)
                    .offsetBy(-sceneView.alternativeBoundsOrigin)
            // if smaller than default size
            if  rectInMask.size.width  < AnnotatorOverlay.minimumBorderedOverlaySize.width  ||
                rectInMask.size.height < AnnotatorOverlay.minimumBorderedOverlaySize.height
            {
                annotator.isFixedAnnotator = true
                annotator.overlay.frame =
                    CGRect(origin: rectInMask.center, size: AnnotatorOverlay.fixedOverlaySize)
                        .offsetBy(AnnotatorOverlay.fixedOverlayOffset)
                        .inset(by: annotator.overlay.outerInsets)
            } else {
                annotator.isFixedAnnotator = false
                annotator.overlay.frame =
                    rectInMask
                        .inset(by: annotator.overlay.outerInsets)
            }
        }
    }
    
    private func updateAnnotatorFrames() {
        annotators.forEach({ updateFrame(of: $0) })
    }
    
    private func updateEditableStates(of annotator: Annotator) {
        let editable = internalSceneTool == .selectionArrow
        if annotator.isEditable != editable { annotator.isEditable = editable }
        updateFrame(of: annotator)
    }
    
    private func updateAnnotatorEditableStates() {
        let editable = internalSceneTool == .selectionArrow
        for annotator in annotators {
            if annotator.isEditable != editable {
                annotator.isEditable = editable
            }
        }
        updateAnnotatorFrames()
    }
    
    private func annotatorLoadRulerMarkers(_ annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            let coordinate = annotator.pixelColor.coordinate
            
            let markerCoordinateH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(coordinate.x), image: RulerMarker.horizontalImage(with: annotator.pixelColor.toNSColor()), imageOrigin: RulerMarker.horizontalOrigin)
            markerCoordinateH.type = .horizontal
            markerCoordinateH.position = .origin
            markerCoordinateH.coordinate = coordinate
            markerCoordinateH.annotator = annotator
            annotator.rulerMarkers.append(markerCoordinateH)
            
            let markerCoordinateV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(coordinate.y), image: RulerMarker.verticalImage(with: annotator.pixelColor.toNSColor()), imageOrigin: RulerMarker.verticalOrigin)
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
            
            let markerOriginH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(origin.x), image: RulerMarker.horizontalImage(), imageOrigin: RulerMarker.horizontalOrigin)
            markerOriginH.type = .horizontal
            markerOriginH.position = .origin
            markerOriginH.coordinate = origin
            markerOriginH.annotator = annotator
            annotator.rulerMarkers.append(markerOriginH)
            
            let markerOriginV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(origin.y), image: RulerMarker.verticalImage(), imageOrigin: RulerMarker.verticalOrigin)
            markerOriginV.type = .vertical
            markerOriginV.position = .origin
            markerOriginV.coordinate = origin
            markerOriginV.annotator = annotator
            annotator.rulerMarkers.append(markerOriginV)
            
            let markerOppositeH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(opposite.x), image: RulerMarker.horizontalImage(), imageOrigin: RulerMarker.horizontalOrigin)
            markerOppositeH.type = .horizontal
            markerOppositeH.position = .opposite
            markerOppositeH.coordinate = opposite
            markerOppositeH.annotator = annotator
            annotator.rulerMarkers.append(markerOppositeH)
            
            let markerOppositeV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(opposite.y), image: RulerMarker.verticalImage(), imageOrigin: RulerMarker.verticalOrigin)
            markerOppositeV.type = .vertical
            markerOppositeV.position = .opposite
            markerOppositeV.coordinate = opposite
            markerOppositeV.annotator = annotator
            annotator.rulerMarkers.append(markerOppositeV)
        }
    }
    
    private func annotatorUnloadRulerMarkers(_ annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.removeMarker($0) })
        annotator.rulerMarkers.removeAll()
    }
    
    private func annotatorReloadRulerMarkers(_ annotator: Annotator) {
        annotatorUnloadRulerMarkers(annotator)
        annotatorLoadRulerMarkers(annotator)
    }
    
    private func annotatorShowRulerMarkers(_ annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.addMarker($0) })
    }
    
    private func annotatorHideRulerMarkers(_ annotator: Annotator) {
        annotator.rulerMarkers.forEach({ $0.ruler?.removeMarker($0) })
    }
    
    func loadAnnotators(from content: Content) throws {
        addAnnotators(for: content.items)
    }
    
    func addAnnotators(for items: [ContentItem]) {
        addAnnotatorsAdvanced(for: items)
    }
    
    private func addAnnotatorsAdvanced(for items: [ContentItem], with overlayAnimationStates: [Int: OverlayAnimationState]? = nil) {
        for item in items {
            guard !annotators.contains(where: { $0.contentItem == item }) else { return }
            let state = overlayAnimationStates?[item.id]
            if item is PixelColor { addAnnotator(for: item as! PixelColor, with: state) }
            else if item is PixelArea { addAnnotator(for: item as! PixelArea, with: state) }
        }
        debugPrint("add annotators \(items.debugDescription)")
    }
    
    @discardableResult
    private func addAnnotator(for color: PixelColor, with overlayAnimationState: OverlayAnimationState? = nil) -> ColorAnnotator {
        let copiedColor = color.copy() as! PixelColor
        let annotator = ColorAnnotator(copiedColor)
        annotatorColorize(annotator)
        annotatorLoadRulerMarkers(annotator)
        if let state = overlayAnimationState {
            annotator.overlay.animationState = state
        }
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelOverlay)
        updateEditableStates(of: annotator)
        return annotator
    }
    
    @discardableResult
    private func addAnnotator(for area: PixelArea, with overlayAnimationState: OverlayAnimationState? = nil) -> AreaAnnotator {
        let copiedArea = area.copy() as! PixelArea
        let annotator = AreaAnnotator(copiedArea)
        annotatorColorize(annotator)
        annotatorLoadRulerMarkers(annotator)
        if let state = overlayAnimationState {
            annotator.overlay.animationState = state
        }
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelOverlay)
        updateEditableStates(of: annotator)
        return annotator
    }
    
    func updateAnnotator(for items: [ContentItem]) {
        let itemIDs = items.compactMap({ $0.id })
        let itemsToRemove = annotators
            .compactMap({ $0.contentItem })
            .filter({ itemIDs.contains($0.id) })
        addAnnotatorsAdvanced(
            for: items,
            with: removeAnnotatorsAdvanced(for: itemsToRemove)
        )
    }
    
    func removeAnnotators(for items: [ContentItem]) {
        removeAnnotatorsAdvanced(for: items)
    }
    
    @discardableResult
    private func removeAnnotatorsAdvanced(for items: [ContentItem]) -> [Int: OverlayAnimationState] {
        var states = [Int: OverlayAnimationState]()
        var removeIndexSet = IndexSet()
        for (index, annotator) in annotators.enumerated() {
            if items.contains(annotator.contentItem) {
                removeIndexSet.insert(index)
                
                states[annotator.contentItem.id] = annotator.overlay.animationState
                annotatorHideRulerMarkers(annotator)
                annotator.overlay.removeFromAnimationGroup()
                annotator.overlay.removeFromSuperview()
            }
        }
        annotators.remove(at: removeIndexSet)
        debugPrint("remove annotators \(items.debugDescription)")
        return states
    }
    
    func highlightAnnotators(for items: [ContentItem], scrollTo: Bool) {
        
        var selectAnnotators: [Annotator] = []
        
        for annotator in annotators {
            if items.contains(annotator.contentItem) {
                selectAnnotators.append(annotator)
            } else if annotator.isSelected {
                annotator.isSelected = false
                annotatorHideRulerMarkers(annotator)
                annotator.overlay.setNeedsDisplay(visibleOnly: false)
            }
        }
        
        selectAnnotators.sort(by: { $0.overlay.frame.size.width * $0.overlay.frame.size.height > $1.overlay.frame.size.width * $1.overlay.frame.size.height })
        
        for annotator in selectAnnotators {
            annotator.overlay.bringToFront()
            if !annotator.isSelected {
                annotator.isSelected = true
                annotatorShowRulerMarkers(annotator)
            }
        }
        
        if scrollTo {  // scroll without changing magnification
            if let item = annotators.last(where: { items.contains($0.contentItem) })?.contentItem {
                if item is PixelColor { previewAction(self, centeredAt: (item as! PixelColor).coordinate) }
                else if item is PixelArea { previewAction(self, toFit: (item as! PixelArea).rect) }
            }
        }
        
        debugPrint("highlight annotators \(items.debugDescription), scroll = \(scrollTo)")
    }
    
}

extension SceneController: ToolbarResponder {
    
    func useAnnotateItemAction(_ sender: Any?) { internalSceneTool = .magicCursor }
    func useMagnifyItemAction(_ sender: Any?)  { internalSceneTool = .magnifyingGlass }
    func useMinifyItemAction(_ sender: Any?)   { internalSceneTool = .minifyingGlass }
    func useSelectItemAction(_ sender: Any?)   { internalSceneTool = .selectionArrow }
    func useMoveItemAction(_ sender: Any?)     { internalSceneTool = .movingHand }
    
    func fitWindowAction(_ sender: Any?)       { sceneMagnify(toFit: wrapperBounds) }
    func fillWindowAction(_ sender: Any?)      { sceneMagnify(toFit: sceneView.bounds.aspectFit(in: wrapperBounds)) }
    
    private func sceneMagnify(toFit rect: CGRect, adjustBorder adjust: Bool = false) {
        let altClipped = sceneClipView.convert(CGSize(width: sceneView.alternativeBoundsOrigin.x, height: sceneView.alternativeBoundsOrigin.y), from: sceneView)
        let fitRect = adjust
            ? rect.insetBy(dx: -(altClipped.width + 1.0), dy: -(altClipped.height + 1.0))
            : rect.insetBy(dx: -1.0, dy: -1.0)
        guard !fitRect.isEmpty else {
            return
        }
        NSAnimationContext.runAnimationGroup({ [unowned self] (context) in
            self.sceneView.animator().magnify(toFit: fitRect)
        }) { [unowned self] in
            self.notifyVisibleRectChanged()
        }
    }
    
}

extension SceneController: ContentDelegate {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentDelegate.addContentItem(of: coordinate)
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        return try contentDelegate.addContentItem(of: rect)
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentDelegate.updateContentItem(item, to: coordinate)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        return try contentDelegate.updateContentItem(item, to: rect)
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentDelegate.updateContentItem(item)
    }
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool) throws -> ContentItem? {
        return try contentDelegate.selectContentItem(item, byExtendingSelection: extend)
    }
    
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool) throws -> [ContentItem]? {
        return try contentDelegate.selectContentItems(items, byExtendingSelection: extend)
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentDelegate.deselectContentItem(item)
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentDelegate.deleteContentItem(of: coordinate)
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentDelegate.deleteContentItem(item)
    }
    
    func deselectAllContentItems() {
        contentDelegate.deselectAllContentItems()
    }
    
}

extension SceneController: ItemPreviewResponder {
    
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
        let centeredPointInWrapper = coordinate.toCGPoint().toPixelCenterCGPoint()
        if !isVisibleWrapperLocation(centeredPointInWrapper) {
            var centeredPoint = sceneView.convert(centeredPointInWrapper, from: wrapper)
            centeredPoint.x -= sceneView.bounds.width / 2.0
            centeredPoint.y -= sceneView.bounds.height / 2.0
            let clipCenteredPoint = sceneClipView.convert(centeredPoint, from: sceneView)
            sceneClipView.animator().setBoundsOrigin(clipCenteredPoint)
        }
    }
    
    func previewAction(_ sender: Any?, toFit rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect(), adjustBorder: true)
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
        let item = marker.annotator?.contentItem.copy()
        if let item = item as? PixelColor {
            _ = try? updateContentItem(item, to: coordinate)
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
                _ = try? updateContentItem(item, to: rect)
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
    
    private var isInComparisonMode: Bool {
        return wrapper.isInComparisonMode
    }
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: (Bool) -> Void) {
        wrapper.setMaskImage(maskImage)
    }
    
    func endPixelMatchComparison() {
        wrapper.setMaskImage(nil)
    }
    
}

extension SceneController {
    
    @objc private func managedTagsDidLoadNotification(_ noti: NSNotification) {
        annotatorColorizeAll()
    }
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.annotatorColorizeAll()
        }
    }
    
    private func annotatorColorize(_ annotator: Annotator) {
        guard let tagName = annotator.contentItem.tags.first,
            let tag = tagListSource.managedTag(of: tagName) else
        {
            annotator.overlay.lineDashColorsHighlighted  = nil
            annotator.overlay.circleFillColorHighlighted = nil
            return
        }
        annotator.overlay
            .lineDashColorsHighlighted  = [NSColor.white.cgColor, tag.color.cgColor]
        annotator.overlay
            .circleFillColorHighlighted = tag.color.cgColor
    }
    
    private func annotatorColorizeAll() {
        annotators.forEach({ annotatorColorize($0) })
    }
    
}

