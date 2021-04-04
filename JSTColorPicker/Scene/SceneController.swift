//
//  SceneController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

class SceneController: NSViewController {
    
    weak var parentTracking    : SceneTracking?
    weak var contentManager    : ContentDelegate!
    weak var tagManager        : TagListSource!
    
    weak var screenshot: Screenshot?
    var annotators: [Annotator] = []
    
    private var lazyColorAnnotators  : [ColorAnnotator] { annotators.lazy.compactMap({ $0 as? ColorAnnotator }) }
    private var lazyAreaAnnotators   : [AreaAnnotator]  { annotators.lazy.compactMap({ $0 as? AreaAnnotator })  }
    
    private var enableForceTouch: Bool {
        get {
            return sceneView.enableForceTouch
        }
        set {
            sceneView.enableForceTouch = newValue
        }
    }
    private var drawBordersInScene: Bool {
        get {
            return sceneBorderView.drawBordersInScene
        }
        set {
            sceneBorderView.drawBordersInScene = newValue
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
    private var drawTagsInScene                 : Bool = false
    private var hideAnnotatorsWhenResize        : Bool = true
    private var hideBordersWhenResize           : Bool = false
    private var hideGridsWhenResize             : Bool = false

    private var _shouldRedrawAnnotatorContents  : Bool = false
    private func setNeedsRedrawAnnotatorContents() {
        _shouldRedrawAnnotatorContents = true
    }
    
    private static let minimumZoomingFactor: CGFloat = pow(2.0, -2)  // 0.25x
    private static let maximumZoomingFactor: CGFloat = pow(2.0, 8)   // 256x
    private static let zoomingFactors: [CGFloat] = [
        0.250, 0.333, 0.500, 0.667, 1.000,
        2.000, 3.000, 4.000, 5.000, 6.000,
        7.000, 8.000, 12.00, 16.00, 32.00,
        64.00, 128.0, 256.0
    ]

    var isCursorMovableByKeyboard                          : Bool                 { wrapperRestrictedMagnification >= SceneController.minimumRecognizableMagnification }
    var isOverlaySelectableByKeyboard                      : Bool                 { sceneOverlayView.hasSelectedOverlay }
    private static let minimumRecognizableMagnification    : CGFloat = 16.0
    
    @IBOutlet private weak var sceneClipView               : SceneClipView!
    @IBOutlet private weak var sceneView                   : SceneScrollView!
    @IBOutlet private weak var sceneBorderView             : SceneBorderView!
    @IBOutlet private weak var sceneGridView               : SceneGridView!
    @IBOutlet private weak var sceneOverlayView            : SceneOverlayView!
    @IBOutlet private weak var sceneEffectView             : SceneEffectView!
    @IBOutlet private weak var sceneTopConstraint          : NSLayoutConstraint!
    @IBOutlet private weak var sceneLeadingConstraint      : NSLayoutConstraint!

    @IBOutlet private      var selectionMenu               : NSMenu!
    @IBOutlet private      var deletionMenu                : NSMenu!
    
    private var horizontalRulerView                        : RulerView            { sceneView.horizontalRulerView as! RulerView    }
    private var verticalRulerView                          : RulerView            { sceneView.verticalRulerView as! RulerView      }
    
    private var wrapper                                    : SceneImageWrapper    { sceneView.documentView as! SceneImageWrapper   }
    var wrapperBounds                                      : CGRect               { wrapper.bounds                                 }
    var wrapperVisibleRect                                 : CGRect               { wrapper.visibleRect                            }
    var wrapperMangnification                              : CGFloat              { sceneView.magnification                        }
    var wrapperRestrictedRect                              : CGRect               { wrapperVisibleRect.intersection(wrapperBounds) }
    var wrapperRestrictedMagnification                     : CGFloat              { max(min(wrapperMangnification, SceneController.maximumZoomingFactor), SceneController.minimumZoomingFactor) }
    
    private func isVisibleLocation(_ location: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(location)
    }
    private func isVisibleWrapperLocation(_ locInWrapper: CGPoint) -> Bool {
        return sceneView.visibleRectExcludingRulers.contains(sceneView.convert(locInWrapper, from: wrapper))
            && wrapperVisibleRect.contains(locInWrapper)
    }
    
    private var internalSceneTool: SceneTool = .arrow {
        didSet {
            updateAnnotatorStates(byRedrawingContents: true)
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
    private var eventMonitors = [Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.minMagnification    = SceneController.minimumZoomingFactor
        sceneView.maxMagnification    = SceneController.maximumZoomingFactor
        sceneView.magnification       = SceneController.minimumZoomingFactor
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
        
        eventMonitors.append(NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] (event) -> NSEvent? in
            guard let self = self, event.window == self.view.window else { return event }
            if self.monitorWindowFlagsChanged(with: event) {
                return nil
            }
            return event
        }!)
        
        eventMonitors.append(NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] (event) -> NSEvent? in
            guard let self = self, event.window == self.view.window else { return event }
            if self.monitorWindowKeyDown(with: event) {
                return nil
            }
            return event
        }!)
        
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillStartLiveMagnify(_:)), name: NSScrollView.willStartLiveMagnifyNotification, object: sceneView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEndLiveMagnify(_:)), name: NSScrollView.didEndLiveMagnifyNotification, object: sceneView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillStartLiveScroll(_:)), name: NSScrollView.willStartLiveScrollNotification, object: sceneView)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEndLiveScroll(_:)), name: NSScrollView.didEndLiveScrollNotification, object: sceneView)
        
        windowActiveNotificationToken = NotificationCenter.default.observe(name: NSWindow.didResignKeyNotification, object: view.window) { [unowned self] _ in
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
        hideAnnotatorsWhenResize = UserDefaults.standard[.hideAnnotatorsWhenResize]
        hideBordersWhenResize = UserDefaults.standard[.hideBordersWhenResize]
        hideGridsWhenResize = UserDefaults.standard[.hideGridsWhenResize]
        usesPredominantAxisScrolling = UserDefaults.standard[.usesPredominantAxisScrolling]
        
        let drawSceneBackground: Bool = UserDefaults.standard[.drawSceneBackground]
        if self.drawSceneBackground != drawSceneBackground {
            self.drawSceneBackground = drawSceneBackground
        }
        
        var shouldNotifySceneBoundsChanged = false
        
        let drawBordersInScene: Bool = UserDefaults.standard[.drawBordersInScene]
        if self.drawBordersInScene != drawBordersInScene {
            self.drawBordersInScene = drawBordersInScene
            shouldNotifySceneBoundsChanged = true
        }
        
        let hideBordersInScene = !drawBordersInScene
        if sceneBorderView.isHidden != hideBordersInScene {
            sceneBorderView.isHidden = hideBordersInScene
        }
        
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

        let drawTagsInScene: Bool = UserDefaults.standard[.drawTagsInScene]
        if self.drawTagsInScene != drawTagsInScene {
            self.drawTagsInScene = drawTagsInScene
            setNeedsRedrawAnnotatorContents()
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
    
    private func applySelectItem(
        at location: CGPoint,
        byShowingOptions menu: Bool,           // option pressed
        byChangingSelection change: Bool,      // double click
        byThroughoutHitting throughout: Bool,  // shift pressed
        byExtendingSelection extend: Bool,     // command pressed
        withEvent event: NSEvent? = NSApp.currentEvent
    ) -> Bool
    {
        let locInMask = sceneOverlayView.convert(location, from: sceneView)
        if let event = event, menu {
            NSMenu.popUpContextMenu(selectionMenu, with: event, for: sceneView)
        } else {
            if change {
                let sortedOverlays = sceneOverlayView.overlays(at: locInMask, bySizeReordering: true)
                let selectedOverlays = sortedOverlays.filter({ $0.isSelected })
                if sortedOverlays.count > 1 && selectedOverlays.count == 1, let selectedOverlay = selectedOverlays.first {
                    // change single selection
                    let zIndexBySize: Bool = UserDefaults.standard[.zIndexBySize]
                    if zIndexBySize {
                        if let selectedOverlayIndex = sortedOverlays.firstIndex(of: selectedOverlay) {
                            var nextOverlayIndex: Int
                            if selectedOverlayIndex < sortedOverlays.count - 1 {
                                nextOverlayIndex = selectedOverlayIndex + 1
                            } else {
                                nextOverlayIndex = 0
                            }
                            let overlayToFocus = sortedOverlays[nextOverlayIndex]
                            guard let annotatorToFocus = annotators.last(where: { $0.overlay === overlayToFocus }) else { return false }
                            if let _ = try? selectContentItem(
                                annotatorToFocus.contentItem,
                                byExtendingSelection: false,
                                byFocusingSelection: true
                            ) {
                                return true
                            }
                        }
                    } else {
                        let filteredAnnotators = annotators.filter({ sortedOverlays.contains($0.overlay) })
                        if let selectedAnnotatorIndex = filteredAnnotators.lastIndex(where: { $0.overlay === selectedOverlay }) {
                            var nextAnnotatorIndex: Int
                            if selectedAnnotatorIndex < filteredAnnotators.count - 1 {
                                nextAnnotatorIndex = selectedAnnotatorIndex + 1
                            } else {
                                nextAnnotatorIndex = 0
                            }
                            let annotatorToFocus = filteredAnnotators[nextAnnotatorIndex]
                            if let _ = try? selectContentItem(
                                annotatorToFocus.contentItem,
                                byExtendingSelection: false,
                                byFocusingSelection: true
                            ) {
                                return true
                            }
                        }
                    }
                } else if throughout {
                    // focus to single selection
                    let sortedSelectedOverlays = selectedOverlays
                        .sorted(by: { $0.bounds.size == $1.bounds.size ? $0.hash > $1.hash : $0.bounds.size > $1.bounds.size })
                    if let overlayToFocus = sortedSelectedOverlays.first {
                        guard let annotatorToFocus = annotators.last(where: { $0.overlay === overlayToFocus }) else { return false }
                        if let _ = try? selectContentItem(
                            annotatorToFocus.contentItem,
                            byExtendingSelection: false,
                            byFocusingSelection: true
                        ) {
                            return true
                        }
                    }
                }
            } else {
                if throughout {
                    let annotatorOverlays = sceneOverlayView.overlays(at: locInMask)
                    if !annotatorOverlays.isEmpty {
                        let annotatorOverlaysSet = Set(annotatorOverlays.filter({ !$0.isSelected }))  // is it safe to identify a view by its hash?
                        let contentItems = annotators
                            .filter({ annotatorOverlaysSet.contains($0.overlay) })
                            .compactMap({ $0.contentItem })
                        if let _ = try? selectContentItems(
                            contentItems,
                            byExtendingSelection: true,
                            byFocusingSelection: true
                        ) {
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
                            if let _ = try? selectContentItem(
                                annotator.contentItem,
                                byExtendingSelection: extend,
                                byFocusingSelection: true
                            ) {
                                return true
                            }
                        }
                    } else {
                        deselectAllContentItems()
                    }
                }
            }
        }
        return false
    }
    
    private func applyDeleteItem(
        at locInWrapper: CGPoint,
        byShowingOptions menu: Bool,     // option pressed
        byIgnoringPopups ignore: Bool,   // user defaults
        withEvent event: NSEvent? = nil
    ) -> Bool
    {
        if let event = event, menu {
            NSMenu.popUpContextMenu(deletionMenu, with: event, for: sceneView)
        } else {
            let locInMask = sceneOverlayView.convert(locInWrapper, from: wrapper)
            if let annotatorView = sceneOverlayView.frontmostOverlay(at: locInMask) {
                if let annotator = annotators.last(where: { $0.overlay === annotatorView }) {
                    if let _ = try? deleteContentItem(annotator.contentItem, byIgnoringPopups: ignore) {
                        return true
                    }
                }
                return false
            }
            if let _ = try? deleteContentItem(of: PixelCoordinate(locInWrapper), byIgnoringPopups: ignore) {
                return true
            }
        }
        return false
    }
    
    private func applyMagnifyItem(at locInWrapper: CGPoint) -> Bool {
        if !canMagnify {
            return false
        }
        if let next = nextMagnificationFactor {
            if isVisibleWrapperLocation(locInWrapper) {
                self.sceneWillStartLiveMagnify()
                NSAnimationContext.runAnimationGroup({ _ in
                    self.sceneView.animator().setMagnification(next, centeredAt: locInWrapper)
                }) { [unowned self] in
                    self.notifyVisibleRectChanged()
                    self.sceneDidEndLiveMagnify()
                }
            } else {
                self.sceneWillStartLiveMagnify()
                NSAnimationContext.runAnimationGroup({ _ in
                    self.sceneView.animator().magnification = next
                }) { [unowned self] in
                    self.notifyVisibleRectChanged()
                    self.sceneDidEndLiveMagnify()
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
                self.sceneWillStartLiveMagnify()
                NSAnimationContext.runAnimationGroup({ _ in
                    self.sceneView.animator().setMagnification(prev, centeredAt: locInWrapper)
                }) { [unowned self] in
                    self.notifyVisibleRectChanged()
                    self.sceneDidEndLiveMagnify()
                }
            } else {
                self.sceneWillStartLiveMagnify()
                NSAnimationContext.runAnimationGroup({ _ in
                    self.sceneView.animator().magnification = prev
                }) { [unowned self] in
                    self.notifyVisibleRectChanged()
                    self.sceneDidEndLiveMagnify()
                }
            }
            return true
        }
        return false
    }
    
    private func shortcutAnnotatorSwitching(at locInWrapper: CGPoint, byForwardingSelection forward: Bool) -> Bool {
        let locInMask = sceneOverlayView.convert(locInWrapper, from: wrapper)
        let sortedOverlays = sceneOverlayView.overlays(at: locInMask, bySizeReordering: true)
        guard sortedOverlays.count > 1 else { return false }

        guard let selectedOverlayIndex = ({ () -> Int? in
            var idx: Int?
            for (overlayIndex, annotatorOverlay) in sortedOverlays.enumerated() {
                if annotatorOverlay.isSelected {
                    if idx == nil {
                        idx = overlayIndex
                    } else {
                        // only one selected overlay accepted
                        return nil
                    }
                }
            }
            return idx
        })() else { return false }

        let zIndexBySize: Bool = UserDefaults.standard[.zIndexBySize]
        if zIndexBySize {
            var nextIndex: Int!
            if selectedOverlayIndex == 0 && forward {
                nextIndex = sortedOverlays.count - 1
            } else if selectedOverlayIndex == sortedOverlays.count - 1 && !forward {
                nextIndex = 0
            } else {
                nextIndex = forward ? selectedOverlayIndex - 1 : selectedOverlayIndex + 1
            }

            if let nextAnnotator = annotators.first(where: { $0.overlay == sortedOverlays[nextIndex] }) {
                if let _ = try? selectContentItems(
                    [nextAnnotator.contentItem],
                    byExtendingSelection: false,
                    byFocusingSelection: true
                ) {
                    return true
                }
            }
        } else {
            let filteredAnnotators = annotators.filter({ sortedOverlays.contains($0.overlay) })

            let selectedOverlay = sortedOverlays[selectedOverlayIndex]
            guard let selectedAnnotatorIndex = filteredAnnotators.firstIndex(where: { $0.overlay == selectedOverlay }) else {
                return false
            }

            var nextIndex: Int!
            if selectedAnnotatorIndex == 0 && forward {
                nextIndex = filteredAnnotators.count - 1
            } else if selectedAnnotatorIndex == filteredAnnotators.count - 1 && !forward {
                nextIndex = 0
            } else {
                nextIndex = forward ? selectedAnnotatorIndex - 1 : selectedAnnotatorIndex + 1
            }

            let nextAnnotator = filteredAnnotators[nextIndex]
            if let _ = try? selectContentItems(
                [nextAnnotator.contentItem],
                byExtendingSelection: false,
                byFocusingSelection: true
            ) {
                return true
            }
        }

        return false
    }
    
    private func requiredStageFor(_ tool: SceneTool, type: SceneState.ManipulatingType) -> Int {
        return enableForceTouch ? 1 : 0
    }
    
    override func mouseUp(with event: NSEvent) {
        var handled = false
        if sceneState.manipulatingType == .leftGeneric {
            let location = sceneView.convert(event.locationInWindow, from: nil)
            if isVisibleLocation(location) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.manipulatingType) {
                    if sceneTool == .selectionArrow {
                        let modifierFlags = event.modifierFlags
                            .intersection(.deviceIndependentFlagsMask)
                        let optionPressed  = modifierFlags.contains(.option) && modifierFlags.subtracting(.option).isEmpty
                        let commandPressed = modifierFlags.contains(.command) && modifierFlags.subtracting(.command).isEmpty
                        let shiftPressed   = modifierFlags.contains(.shift) && modifierFlags.subtracting(.shift).isEmpty
                        let isDoubleClick  = event.clickCount == 2
                        handled = applySelectItem(
                            at: location,
                            byShowingOptions: optionPressed,
                            byChangingSelection: isDoubleClick,
                            byThroughoutHitting: shiftPressed,
                            byExtendingSelection: commandPressed,
                            withEvent: event
                        )
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
        if sceneState.manipulatingType == .rightGeneric {
            let locInWrapper = wrapper.convert(event.locationInWindow, from: nil)
            if isVisibleWrapperLocation(locInWrapper) {
                if sceneState.stage >= requiredStageFor(sceneTool, type: sceneState.manipulatingType) {
                    if sceneTool == .magicCursor || sceneTool == .selectionArrow {
                        let modifierFlags = event.modifierFlags
                            .intersection(.deviceIndependentFlagsMask)
                        let optionPressed  = modifierFlags.contains(.option) && modifierFlags.subtracting(.option).isEmpty
                        let ignoreInvalidDeletion: Bool = UserDefaults.standard[.ignoreInvalidDeletion]
                        handled = applyDeleteItem(
                            at: locInWrapper,
                            byShowingOptions: optionPressed,
                            byIgnoringPopups: ignoreInvalidDeletion,
                            withEvent: event
                        )
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
        var needsUpdate = false
        var handled = false
        let modifierFlags = event?.modifierFlags ?? NSEvent.modifierFlags
        switch modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .command])
        {
        case [.option]:
            needsUpdate = useOptionModifiedSceneTool(forceReset)
            handled = true
        case [.control]:
            needsUpdate = useCommandModifiedSceneTool(forceReset)
            handled = true
        default:
            needsUpdate = useSelectedSceneTool(forceReset)
            handled = false
        }
        if needsUpdate && sceneView.isMouseInside {
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
        if internalSceneTool != windowSelectedSceneTool {
            internalSceneTool = windowSelectedSceneTool
        }
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
        
        guard isCursorMovableByKeyboard else { return false }
        
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
            
            self.sceneWillStartLiveScroll()
            NSAnimationContext.runAnimationGroup({ _ in
                self.sceneClipView.animator().setBoundsOrigin(clipOrigin)
            }) { [unowned self] in
                self.notifyVisibleRectChanged()
                self.sceneDidEndLiveScroll()
            }
            
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
        
        sceneRawColorDidChange(sceneView, at: PixelCoordinate(toWrapperPoint))
        return true
    }
    
    @discardableResult
    private func shortcutCopyPixelColor(at locInWrapper: CGPoint) -> Bool {
        guard isVisibleWrapperLocation(locInWrapper) else { return false }
        if let _ = try? copyContentItem(of: PixelCoordinate(locInWrapper)) {
            return true
        }
        return false
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
                    else if specialKey == .delete || specialKey == .deleteForward || specialKey == .backspace {
                        let optionPressed = flags.contains(.option)
                        let ignoreInvalidDeletion: Bool = UserDefaults.standard[.ignoreInvalidDeletion]
                        return applyDeleteItem(at: locInWrapper, byShowingOptions: optionPressed, byIgnoringPopups: ignoreInvalidDeletion)
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
        eventMonitors.forEach({ NSEvent.removeMonitor($0) })
        eventMonitors.removeAll()
        debugPrint("\(className):\(#function)")
    }
    
}

extension SceneController: ScreenshotLoader {
    
    private func reloadSceneRulerConstraints() {
        sceneTopConstraint.constant = sceneView.alternativeBoundsOrigin.y
        sceneLeadingConstraint.constant = sceneView.alternativeBoundsOrigin.x
    }
    
    func load(_ screenshot: Screenshot) throws {
        
        guard let image = screenshot.image else {
            throw Screenshot.Error.invalidImage
        }
        
        guard let content = screenshot.content else {
            throw Screenshot.Error.invalidContent
        }
        
        self.screenshot = screenshot
        renderImage(image)
        
        removeAllAnnotators()
        try loadAnnotators(from: content)
        
    }
    
}

extension SceneController: SceneTracking, SceneActionTracking {
    
    @objc private func sceneWillStartLiveMagnify(_ notification: NSNotification? = nil) {
        if !sceneOverlayView.isHidden {
            hideSceneOverlays()
        }
        debugPrint("\(className):\(#function)")
    }
    
    @objc private func sceneDidEndLiveMagnify(_ notification: NSNotification? = nil) {
        if sceneOverlayView.isHidden {
            showSceneOverlays()
        }
        debugPrint("\(className):\(#function)")
    }
    
    @objc private func sceneWillStartLiveScroll(_ notification: NSNotification? = nil) {
        debugPrint("\(className):\(#function)")
    }
    
    @objc private func sceneDidEndLiveScroll(_ notification: NSNotification? = nil) {
        debugPrint("\(className):\(#function)")
    }
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        if !sceneOverlayView.isHidden {
            updateAnnotatorStates()
        }
        var sceneTrackings: [SceneTracking] = [
            sceneBorderView,
            sceneGridView,
            sceneOverlayView,
        ]
        if parentTracking != nil {
            sceneTrackings.append(parentTracking!)
        }
        sceneTrackings.forEach({ $0.sceneVisibleRectDidChange(sender, to: rect, of: magnification) })
    }
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        parentTracking?.sceneRawColorDidChange(sender, at: coordinate)
    }
    
    func sceneRawAreaDidChange(_ sender: SceneScrollView?, to rect: PixelRect) {
        parentTracking?.sceneRawAreaDidChange(sender, to: rect)
    }
    
    func sceneWillStartLiveResize(_ sender: SceneScrollView?) {
        debugPrint("\(className):\(#function)")
    }
    
    func sceneDidEndLiveResize(_ sender: SceneScrollView?) {
        debugPrint("\(className):\(#function)")
    }
    
    func sceneMagnifyingGlassActionDidEnd(_ sender: SceneScrollView?, to rect: PixelRect) {
        sceneMagnify(toFit: rect.toCGRect(), adjustBorder: true)
    }
    
    func sceneMagicCursorActionDidEnd(_ sender: SceneScrollView?, to rect: PixelRect) {
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
    
    func sceneMagicCursorActionDidEnd(_ sender: SceneScrollView?, to coordinate: PixelCoordinate) {
        if let overlay = sceneState.manipulatingOverlay as? ColorAnnotatorOverlay {
            guard let annotator = lazyColorAnnotators.last(where: { $0.pixelOverlay === overlay }) else { return }
            guard annotator.pixelColor.coordinate != coordinate else { return }
            guard let item = annotator.contentItem.copy() as? PixelColor else { return }
            _ = try? updateContentItem(item, to: coordinate)
        }
    }
    
    func sceneMovingHandActionWillBegin(_ sender: SceneScrollView?) {
        sceneWillStartLiveScroll()
    }
    
    func sceneMovingHandActionDidEnd(_ sender: SceneScrollView?) {
        sceneDidEndLiveScroll()
    }
    
    private func notifyVisibleRectChanged() {
        sceneVisibleRectDidChange(sceneView, to: wrapperRestrictedRect, of: wrapperRestrictedMagnification)
    }
    
}

extension SceneController: SceneToolSource {
    
    var sceneTool: SceneTool {
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
    
    var sceneState: SceneState
    {
        get { internalSceneState            }
        set { internalSceneState = newValue }
    }
    
    func beginEditing() -> EditableOverlay? {
        let locInMask = sceneOverlayView.convert(sceneState.beginLocation, from: sceneView)
        guard let overlay = sceneOverlayView.frontmostOverlay(at: locInMask) else { return nil }
        overlay.setEditing(at: sceneOverlayView.convert(locInMask, to: overlay))
        return overlay
    }
    
}

extension SceneController: SceneEffectViewSource {
    
    var sourceSceneEffectView: SceneEffectView {
        return sceneEffectView
    }
    
}

extension SceneController: AnnotatorSource {
    
    private func hideSceneOverlays() {
        if hideAnnotatorsWhenResize && !sceneOverlayView.isHidden {
            sceneOverlayView.isHidden = true
        }
        if hideBordersWhenResize && !sceneBorderView.isHidden {
            sceneBorderView.isHidden = true
        }
        if hideGridsWhenResize && !sceneGridView.isHidden {
            sceneGridView.isHidden = true
        }
    }
    
    private func showSceneOverlays() {
        if sceneOverlayView.isHidden {
            sceneOverlayView.isHidden = false
        }
        if drawBordersInScene && sceneBorderView.isHidden {
            sceneBorderView.isHidden = false
        }
        if drawGridsInScene && sceneGridView.isHidden {
            sceneGridView.isHidden = false
        }
        updateAnnotatorStates()
    }
    
    private func updateStates(of annotator: Annotator, byRedrawingContents redraw: Bool = false) {
        let isEditable = internalSceneTool == .selectionArrow
        let isRevealable = internalSceneTool == .movingHand
        if annotator.isEditable != isEditable {
            annotator.isEditable = isEditable
        }
        if let annotator = annotator as? ColorAnnotator {
            if annotator.revealStyle != .fixed {
                annotator.revealStyle = .fixed
            }
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
                if annotator.revealStyle != .fixed {
                    annotator.revealStyle = .fixed
                }
                annotator.overlay.frame =
                    CGRect(origin: rectInMask.center, size: AnnotatorOverlay.fixedOverlaySize)
                        .offsetBy(AnnotatorOverlay.fixedOverlayOffset)
                        .inset(by: annotator.overlay.outerInsets)
            } else {
                let revealStyle: AnnotatorOverlay.RevealStyle =
                    drawTagsInScene ? (isRevealable ? .centered : .none) : .none
                if annotator.revealStyle != revealStyle {
                    annotator.revealStyle = revealStyle
                }
                annotator.overlay.frame =
                    rectInMask
                        .inset(by: annotator.overlay.outerInsets)
            }
        }
        if redraw {
            annotator.overlay.needsDisplay = true
        }
    }
    
    private func updateAnnotatorStates(byRedrawingContents redraw: Bool = false) {
        var shouldRedraw = redraw
        if _shouldRedrawAnnotatorContents {
            _shouldRedrawAnnotatorContents = false
            shouldRedraw = true
        }
        annotators.forEach({ updateStates(of: $0, byRedrawingContents: shouldRedraw) })
    }
    
    private func annotatorLoadRulerMarkers(_ annotator: Annotator) {
        if let annotator = annotator as? ColorAnnotator {
            let coordinate = annotator.pixelColor.coordinate

            let markerCoordinateH = RulerMarker(rulerView: horizontalRulerView, markerLocation: CGFloat(coordinate.x), image: RulerMarker.horizontalImage(), imageOrigin: RulerMarker.horizontalOrigin)
            markerCoordinateH.type = .horizontal
            markerCoordinateH.position = .origin
            markerCoordinateH.coordinate = coordinate
            markerCoordinateH.annotator = annotator
            annotator.rulerMarkers.append(markerCoordinateH)
            
            let markerCoordinateV = RulerMarker(rulerView: verticalRulerView, markerLocation: CGFloat(coordinate.y), image: RulerMarker.verticalImage(), imageOrigin: RulerMarker.verticalOrigin)
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
        annotatorLoadRulerMarkers(annotator)
        annotatorColorize(annotator)
        if let state = overlayAnimationState {
            annotator.overlay.animationState = state
        }
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelOverlay)
        updateStates(of: annotator)
        return annotator
    }
    
    @discardableResult
    private func addAnnotator(for area: PixelArea, with overlayAnimationState: OverlayAnimationState? = nil) -> AreaAnnotator {
        let copiedArea = area.copy() as! PixelArea
        let annotator = AreaAnnotator(copiedArea)
        annotatorLoadRulerMarkers(annotator)
        annotatorColorize(annotator)
        if let state = overlayAnimationState {
            annotator.overlay.animationState = state
        }
        annotators.append(annotator)
        sceneOverlayView.addSubview(annotator.pixelOverlay)
        updateStates(of: annotator)
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
    
    private func removeAllAnnotators() {
        var removeIndexSet = IndexSet()
        for (index, annotator) in annotators.enumerated() {
            removeIndexSet.insert(index)
            
            annotatorHideRulerMarkers(annotator)
            annotator.overlay.removeFromAnimationGroup()
            annotator.overlay.removeFromSuperview()
        }
        annotators.remove(at: removeIndexSet)
        debugPrint("remove all annotators")
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
                if item is PixelColor { previewAction(nil, atCoordinate: (item as! PixelColor).coordinate, animated: true) }
                else if item is PixelArea { previewAction(nil, toFit: (item as! PixelArea).rect) }
            }
        }
        
        debugPrint("highlight annotators \(items.debugDescription), scroll = \(scrollTo)")
        
    }
    
}

extension SceneController: ToolbarResponder {
    
    func useAnnotateItemAction(_ sender: Any?) { if internalSceneTool != .magicCursor { internalSceneTool = .magicCursor } }
    func useMagnifyItemAction(_ sender: Any?)  { if internalSceneTool != .magnifyingGlass { internalSceneTool = .magnifyingGlass } }
    func useMinifyItemAction(_ sender: Any?)   { if internalSceneTool != .minifyingGlass { internalSceneTool = .minifyingGlass } }
    func useSelectItemAction(_ sender: Any?)   { if internalSceneTool != .selectionArrow { internalSceneTool = .selectionArrow } }
    func useMoveItemAction(_ sender: Any?)     { if internalSceneTool != .movingHand { internalSceneTool = .movingHand } }
    
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
        self.sceneWillStartLiveMagnify()
        NSAnimationContext.runAnimationGroup({ _ in
            self.sceneView.animator().magnify(toFit: fitRect)
        }) { [unowned self] in
            self.notifyVisibleRectChanged()
            self.sceneDidEndLiveMagnify()
        }
    }
    
}

extension SceneController: ContentDelegate {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentManager.addContentItem(of: coordinate)
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        return try contentManager.addContentItem(of: rect)
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentManager.updateContentItem(item, to: coordinate)
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        return try contentManager.updateContentItem(item, to: rect)
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentManager.updateContentItem(item)
    }
    
    func updateContentItems(_ items: [ContentItem]) throws -> [ContentItem]? {
        return try contentManager.updateContentItems(items)
    }
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> ContentItem? {
        return try contentManager.selectContentItem(item, byExtendingSelection: extend, byFocusingSelection: focus)
    }
    
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> [ContentItem]? {
        return try contentManager.selectContentItems(items, byExtendingSelection: extend, byFocusingSelection: focus)
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        return try contentManager.deselectContentItem(item)
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        return try contentManager.deleteContentItem(of: coordinate, byIgnoringPopups: ignore)
    }
    
    func deleteContentItem(_ item: ContentItem, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        return try contentManager.deleteContentItem(item, byIgnoringPopups: ignore)
    }
    
    func deselectAllContentItems() {
        contentManager.deselectAllContentItems()
    }

    func copyContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        return try contentManager.copyContentItem(of: coordinate)
    }
    
}

extension SceneController: ItemPreviewResponder {
    
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        guard magnification >= SceneController.minimumZoomingFactor && magnification <= SceneController.maximumZoomingFactor else { return }
        if let sender = sender {
            if sender.previewStage == .begin {
                sceneWillStartLiveMagnify()
            }
            sceneView.magnification = magnification
            if sender.previewStage == .end {
                sceneDidEndLiveMagnify()
            }
        } else {
            sceneWillStartLiveMagnify()
            sceneView.magnification = magnification
            sceneDidEndLiveMagnify()
        }
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        var centeredPoint = sceneView.convert(point, from: wrapper)
        centeredPoint.x -= sceneView.bounds.width / 2.0
        centeredPoint.y -= sceneView.bounds.height / 2.0
        let clipCenteredPoint = sceneClipView.convert(centeredPoint, from: sceneView)
        if animated {
            self.sceneWillStartLiveScroll()
            NSAnimationContext.runAnimationGroup({ _ in
                self.sceneClipView.animator().setBoundsOrigin(clipCenteredPoint)
            }) { [unowned self] in
                self.notifyVisibleRectChanged()
                self.sceneDidEndLiveScroll()
            }
        } else {
            if let sender = sender {
                if sender.previewStage == .begin {
                    sceneWillStartLiveScroll()
                }
                sceneClipView.setBoundsOrigin(clipCenteredPoint)
                notifyVisibleRectChanged()
                if sender.previewStage == .end {
                    sceneDidEndLiveScroll()
                }
            } else {
                sceneWillStartLiveScroll()
                sceneClipView.setBoundsOrigin(clipCenteredPoint)
                notifyVisibleRectChanged()
                sceneDidEndLiveScroll()
            }
        }
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        let centeredPointInWrapper = coordinate.toCGPoint().toPixelCenterCGPoint()
        if !isVisibleWrapperLocation(centeredPointInWrapper) {
            previewAction(sender, atAbsolutePoint: centeredPointInWrapper, animated: animated)
        }
    }
    
    func previewAction(_ sender: ItemPreviewSender?, toFit rect: PixelRect) {
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
        annotatorColorizeAll(byRedrawingContents: true)
    }
    
    @objc private func managedTagsDidChangeNotification(_ noti: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            self?.annotatorColorizeAll(byRedrawingContents: true)
        }
    }
    
    private func annotatorColorize(_ annotator: Annotator, byRedrawingContents redraw: Bool = false) {
        guard let tagName = annotator.contentItem.tags.first,
            let tag = tagManager.managedTag(of: tagName) else
        {
            annotator.overlay.associatedLabelColor = nil
            annotator.overlay.associatedBackgroundColor = nil
            annotator.overlay.lineDashColorsHighlighted  = nil
            annotator.overlay.circleFillColorHighlighted = nil

            if redraw {
                annotator.overlay.needsDisplay = true
            }

            annotator.rulerMarkers.forEach { (marker) in
                if marker.type == .horizontal {
                    marker.image = RulerMarker.horizontalImage()
                } else if marker.type == .vertical {
                    marker.image = RulerMarker.verticalImage()
                }
            }

            if redraw {
                verticalRulerView.needsDisplay = true
                horizontalRulerView.needsDisplay = true
            }

            return
        }

        annotator.overlay.associatedLabelColor = tag.color
        annotator.overlay.associatedBackgroundColor = tag.color.withAlphaComponent(0.2)
        annotator.overlay.lineDashColorsHighlighted  = [NSColor.white.cgColor, tag.color.cgColor]
        annotator.overlay.circleFillColorHighlighted = tag.color.cgColor

        if redraw {
            annotator.overlay.needsDisplay = true
        }

        annotator.rulerMarkers.forEach { (marker) in
            if marker.type == .horizontal {
                marker.image = RulerMarker.horizontalImage(fillColor: tag.color, strokeColor: nil)
            } else if marker.type == .vertical {
                marker.image = RulerMarker.verticalImage(fillColor: tag.color, strokeColor: nil)
            }
        }

        if redraw {
            verticalRulerView.needsDisplay = true
            horizontalRulerView.needsDisplay = true
        }
    }
    
    private func annotatorColorizeAll(byRedrawingContents redraw: Bool = false) {
        annotators.forEach({ annotatorColorize($0, byRedrawingContents: redraw) })
    }
    
}

extension SceneController: NSMenuItemValidation, NSMenuDelegate {

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let event = view.window?.currentEvent else { return }

        let locInMask = sceneOverlayView.convert(event.locationInWindow, from: nil)
        let annotatorOverlays = sceneOverlayView.overlays(at: locInMask)
        let selectedOverlays = annotatorOverlays.filter({ $0.isSelected })
        let contentItems: [ContentItem]
        let zIndexBySize: Bool = UserDefaults.standard[.zIndexBySize]
        if zIndexBySize {
            contentItems = annotators
                .filter({ annotatorOverlays.contains($0.overlay) })
                .sorted(by: {
                    $0.overlay.bounds.size == $1.overlay.bounds.size
                        ? $0.overlay.hash > $1.overlay.hash
                        : $0.overlay.bounds.size > $1.overlay.bounds.size

                })
                .map({ $0.contentItem })
        } else {
            contentItems = annotators
                .filter({ annotatorOverlays.contains($0.overlay) })
                .map({ $0.contentItem })
        }

        let selectedContentItems = annotators
            .filter({ selectedOverlays.contains($0.overlay) })
            .map({ $0.contentItem })

        let menuItems = contentItems.map { (contentItem) -> NSMenuItem in
            let menuItem = NSMenuItem(title: String(format: NSLocalizedString("Item #%ld: %@", comment: "Item #%@: %@"), contentItem.id, contentItem.description), action: nil, keyEquivalent: "")
            menuItem.target = self
            menuItem.state = selectedContentItems.contains(contentItem) ? .on : .off
            menuItem.representedObject = contentItem
            return menuItem
        }

        if menu == selectionMenu {
            menuItems.forEach({ $0.action = #selector(selectContentItemFromMenuItem(_:)) })
            menu.items = menuItems
        }
        else if menu == deletionMenu {
            menuItems.forEach({ $0.action = #selector(deleteContentItemFromMenuItem(_:)) })
            menu.items = menuItems
        }
    }

    @objc private func selectContentItemFromMenuItem(_ menuItem: NSMenuItem) {
        guard let contentItem = menuItem.representedObject as? ContentItem else { return }
        if menuItem.state != .on {
            _ = try? selectContentItem(
                contentItem,
                byExtendingSelection: true,
                byFocusingSelection: true
            )
        } else {
            _ = try? deselectContentItem(contentItem)
        }
    }

    @objc private func deleteContentItemFromMenuItem(_ menuItem: NSMenuItem) {
        guard let contentItem = menuItem.representedObject as? ContentItem else { return }
        _ = try? deleteContentItem(contentItem, byIgnoringPopups: false)
    }

}

