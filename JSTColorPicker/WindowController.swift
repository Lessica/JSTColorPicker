//
//  WindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


// MARK: - NSToolbarItemGroup

private extension NSToolbarItemGroup {
    var selectedItemIdentifier: NSToolbarItem.Identifier? {
        get {
            guard selectionMode == .selectOne else { fatalError("this property only works when selectionMode == .selectOne") }
            guard selectedIndex >= 0 && selectedIndex < subitems.count else { return nil }
            return subitems[selectedIndex].itemIdentifier
        }
        set {
            guard selectionMode == .selectOne else { fatalError("this property only works when selectionMode == .selectOne") }
            guard let itemIndexToSelect = subitems.firstIndex(where: { $0.itemIdentifier == newValue }) else { return }
            selectedIndex = itemIndexToSelect
        }
    }
}


// MARK: - WindowController

private var windowCount = 0

class WindowController: NSWindowController {
    
    
    // MARK: - Tabbing
    
    weak var tabDelegate: TabDelegate!
    
    override func newWindowForTab(_ sender: Any?) {
        guard let window = window else { preconditionFailure("window not loaded") }
        guard let newWindow = tabDelegate.addManagedWindow(windowController: WindowController.newEmptyWindow())?.window else { preconditionFailure() }
        window.addTabbedWindow(newWindow, ordered: .above)
        newWindow.makeKeyAndOrderFront(self)
        inspectWindowHierarchy()
    }
    
    private func inspectWindowHierarchy() {
        guard let rootWindow = window else { return }
        print("Root window", rootWindow, rootWindow.title, "has tabs:")
        rootWindow.tabbedWindows?.forEach { window in
            print("- ", window, window.title, "isKey =", window.isKeyWindow, ", isMain =", window.isMainWindow, " at ", window.frame)
        }
    }
    
    static func newEmptyWindow() -> WindowController {
        let windowStoryboard = NSStoryboard(name: "Main", bundle: nil)
        return windowStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("MainWindow")) as! WindowController
    }
    
    
    // MARK: - Content Controller
    
    var splitController: SplitController! {
        return self.window?.contentViewController?.children.first as? SplitController
    }
    
    var contentController        : ContentController!       { splitController.contentController }
    var sceneController          : SceneController!         { splitController.sceneController   }
    var segmentController        : SegmentController!       { splitController.segmentController }
    
    
    // MARK: - Document States
    
    @objc dynamic internal weak var screenshot  : Screenshot?
    internal var documentScreenshot             : Screenshot?      { document as? Screenshot }
    private  var documentState                  : Screenshot.State { screenshot?.state ?? .notLoaded }
    private  var documentObservations           : [NSKeyValueObservation]?
    private  var lastStoredMagnification        : CGFloat?
    private  var _windowSubtitle                : String?
    private  var isInComparisonMode             : Bool = false
    
    lazy     var pixelMatchService              : PixelMatchService = {
        return PixelMatchService()
    }()
    
    private  var isScreenshotActionAllowed      : Bool
    {
        return AppDelegate.shared.applicationCheckScreenshotHelper().exists && (
            documentState.isReadable || !documentState.isLoaded
        )
    }
    
    
    // MARK: - Toolbar Items
    
    @IBOutlet weak var toolbar                         : NSToolbar!
    
    private   lazy var openItem                        : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .openItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Open", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Open", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Open (⌘O): Load a PNG image file from file system.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "plus.rectangle", accessibilityDescription: "Open")
        item.action = #selector(NSDocumentController.openDocument(_:))
        return item
    }()
    
    private   lazy var annotateItem                    : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .annotateItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Annotate", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Annotate", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Magic Cursor: Add, or delete annotations.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Annotate")
        item.target = self
        item.action = #selector(useAnnotateItemAction(_:))
        return item
    }()
    
    private   lazy var selectItem                      : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .selectItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Select", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Select", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Selection Arrow: View, select, or modify annotations.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "cursorarrow.and.square.on.square.dashed", accessibilityDescription: "Select")
        item.target = self
        item.action = #selector(useSelectItemAction(_:))
        return item
    }()
    
    private   lazy var magnifyItem                     : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .magnifyItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Magnify", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Magnify", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Magnifying Glass: Zoom in at a preset scale, supports zooming into a specified area.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Magnify")
        item.target = self
        item.action = #selector(useMagnifyItemAction(_:))
        return item
    }()
    
    private   lazy var minifyItem                      : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .minifyItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Minify", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Minify", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Minifying Glass: Zoom out at a preset scale.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Minify")
        item.target = self
        item.action = #selector(useMinifyItemAction(_:))
        return item
    }()
    
    private   lazy var moveItem                        : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .moveItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Move", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Move", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Moving Hand: Drag to move the scene, or view the major tag of annotations.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left", accessibilityDescription: "Move")
        item.target = self
        item.action = #selector(useMoveItemAction(_:))
        return item
    }()
    
    private   lazy var fitWindowItem                   : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .fitWindowItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Fit Window", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Fit Window", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Fit Window: Scale the view to fit the window size.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "aspectratio", accessibilityDescription: "Fit Window")
        item.target = self
        item.action = #selector(fitWindowAction(_:))
        return item
    }()
    
    private   lazy var fillWindowItem                  : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .fillWindowItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Fill Window", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Fill Window", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Fill Window: Scale the view to fill the window size.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "arrow.up.right.and.arrow.down.left.rectangle", accessibilityDescription: "Fill Window")
        item.target = self
        item.action = #selector(fillWindowAction(_:))
        return item
    }()
    
    private   lazy var screenshotItem                  : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .screenshotItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Take Screenshot", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Take Screenshot", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Take Screenshot: Take a screenshot directly from the selected devices.", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "Take Screenshot")
        item.target = self
        item.action = #selector(screenshotAction(_:))
        return item
    }()
    
    private   lazy var sidebarItem                     : NSToolbarItem = {
        let item = NSToolbarItem(itemIdentifier: .sidebarItem)
        item.isBordered = true
        item.autovalidates = true
        item.label = NSLocalizedString("Sidebar", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.paletteLabel = NSLocalizedString("Sidebar", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.toolTip = NSLocalizedString("Toggle Sidebar", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.image = NSImage(systemSymbolName: "sidebar.squares.right", accessibilityDescription: "Sidebar")
        item.action = #selector(NSSplitViewController.toggleSidebar(_:))
        return item
    }()
    
    internal       var selectedSceneToolIdentifier     : NSToolbarItem.Identifier? { sceneToolsGroup.selectedItemIdentifier }
    
    private   lazy var sceneToolsGroup                 : NSToolbarItemGroup = {
        let item = NSToolbarItemGroup(itemIdentifier: .sceneToolGroup)
        item.isBordered = true
        item.autovalidates = true
        item.controlRepresentation = .automatic
        item.selectionMode = .selectOne
        item.label = NSLocalizedString("Scene Tools", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.subitems = [annotateItem, selectItem, magnifyItem, minifyItem, moveItem]
        return item
    }()
    
    private   lazy var previewToolsGroup               : NSToolbarItemGroup = {
        let item = NSToolbarItemGroup(itemIdentifier: .sceneActionGroup)
        item.isBordered = true
        item.autovalidates = true
        item.controlRepresentation = .automatic
        item.selectionMode = .momentary
        item.label = NSLocalizedString("Preview Tools", comment: "com.jst.JSTColorPicker.ToolbarItem")
        item.subitems = [fitWindowItem, fillWindowItem]
        return item
    }()
    
    private   lazy var sidebarTrackingSeparatorItem    : NSTrackingSeparatorToolbarItem = {
        return NSTrackingSeparatorToolbarItem(identifier: .sidebarTrackingSeparator, splitView: splitController.splitView, dividerIndex: 1)
    }()
    
    
    // MARK: - TouchBar Items
    
    @IBOutlet weak var mainTouchBar                    : NSTouchBar!
    @IBOutlet weak var groupedTouchBar                 : NSTouchBar!
    @IBOutlet weak var sliderTouchBar                  : NSTouchBar!
    
    @IBOutlet weak var touchBarOpenButton              : NSButton!
    @IBOutlet weak var touchBarSceneToolControl        : NSSegmentedControl!
    @IBOutlet weak var touchBarSceneActionControl      : NSSegmentedControl!
    @IBOutlet weak var touchBarScreenshot              : NSButton!
    
    internal       var previewStage                    : ItemPreviewStage = .none
    @IBOutlet weak var touchBarPopoverItem             : NSPopoverTouchBarItem!
    @IBOutlet weak var touchBarPreviewSliderItem       : NSSliderTouchBarItem!
    @IBOutlet weak var touchBarPreviewSlider           : NSSlider!
    
    
    // MARK: - Alert Sheets
    
    private var currentAlertSheet: NSAlert?
    var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    func showSheet(_ sheet: NSAlert?, completionHandler: ((NSApplication.ModalResponse) -> Void)?) {
        guard let window = window else { return }
        if let currentAlertSheet = currentAlertSheet {
            currentAlertSheet.window.orderOut(self)
            window.endSheet(currentAlertSheet.window)
        }
        currentAlertSheet = nil
        sheet?.beginSheetModal(for: window, completionHandler: completionHandler)
        currentAlertSheet = sheet
    }
    
    
    // MARK: - Life Cycle
    
    override func windowDidLoad() {
        super.windowDidLoad()
        windowCount += 1
        
        NSColorPanel.shared.delegate = self
        splitController.parentTracking = self
        
        if let window = window {
            window.title = String(format: NSLocalizedString("Untitled #%d", comment: "initializeController"), windowCount)
            sceneToolsGroup.selectedItemIdentifier = .annotateItem
            syncToolbarState(window)
            
            touchBarPreviewSlider.isEnabled = documentState.isLoaded
            ShortcutGuideWindowController.registerShortcutGuideForWindow(window)
        }
        
        #if APP_STORE
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(productTypeDidChange(_:)),
            name: PurchaseManager.productTypeDidChangeNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        debugPrint("\(className):\(#function)")
    }
    
    
    // MARK: - Comparison
    
    func beginPixelMatchComparison(to image: PixelImage) {
        guard let currentPixelImage = screenshot?.image else { return }
        
        isInComparisonMode = true
        let loadingAlert = NSAlert()
        loadingAlert.messageText = NSLocalizedString("Calculating Difference…", comment: "beginPixelMatchComparison(to:)")
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "beginPixelMatchComparison(to:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        showSheet(loadingAlert, completionHandler: nil)
        
        let queue: DispatchQueue = UserDefaults.standard[.pixelMatchBackgroundMode] ?
            DispatchQueue.global(qos: .utility) : DispatchQueue.global(qos: .userInitiated)
        queue.async { [weak self] in
            guard let self = self else { return }
            do {
                let maskImage = try self.pixelMatchService.performConcurrentPixelMatch(currentPixelImage.pixelImageRepresentation, image.pixelImageRepresentation)
                DispatchQueue.main.sync { [weak self] in
                    self?.splitController.beginPixelMatchComparison(to: image, with: maskImage) { [weak self] (shouldExit) in
                        if shouldExit {
                            self?.endPixelMatchComparison()
                        }
                    }
                    self?.showSheet(nil, completionHandler: nil)
                }
            } catch {
                DispatchQueue.main.sync { [weak self] in
                    let errorAlert = NSAlert(error: error)
                    self?.showSheet(errorAlert, completionHandler: { [weak self] (resp) in
                        self?.isInComparisonMode = false
                    })
                }
            }
        }
    }
    
    var shouldEndPixelMatchComparison: Bool {
        return !pixelMatchService.isProcessing && isInComparisonMode
    }
    
    func endPixelMatchComparison() {
        if shouldEndPixelMatchComparison {
            splitController.endPixelMatchComparison()
            showSheet(nil, completionHandler: nil)
            isInComparisonMode = false
        }
    }
    
}


// MARK: - NSMenuItemValidation, NSToolbarItemValidation

extension WindowController: NSMenuItemValidation, NSToolbarItemValidation {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if
            /* Scene Actions */
               menuItem.action == #selector(windowUseAnnotateItemAction(_:))
            || menuItem.action == #selector(windowUseSelectItemAction(_:))
            || menuItem.action == #selector(windowUseMagnifyItemAction(_:))
            || menuItem.action == #selector(windowUseMinifyItemAction(_:))
            || menuItem.action == #selector(windowUseMoveItemAction(_:))
            || menuItem.action == #selector(windowFitWindowAction(_:))
            || menuItem.action == #selector(windowFillWindowAction(_:))
            || menuItem.action == #selector(windowZoomInAction(_:))
            || menuItem.action == #selector(windowZoomOutAction(_:))
            || menuItem.action == #selector(windowZoomToAction(_:))
            || menuItem.action == #selector(windowNavigateToAction(_:))
            || menuItem.action == #selector(windowSetupSmartZoomAction(_:))
            /* Annotator Actions */
            || menuItem.action == #selector(windowQuickAnnotatorAction(_:))
            || menuItem.action == #selector(windowQuickCopyAnnotatorAction(_:))
            || menuItem.action == #selector(windowSelectPreviousAnnotatorAction(_:))
            || menuItem.action == #selector(windowSelectNextAnnotatorAction(_:))
            || menuItem.action == #selector(windowRemoveAnnotatorAction(_:))
            || menuItem.action == #selector(windowListRemovableAnnotatorAction(_:))
        {
            guard documentState.isLoaded else { return false }
            
            /* Menu Shortcuts */
            if menuItem.action == #selector(windowSetupSmartZoomAction(_:)) {
                return sceneController.isSmartZoomMagnificationAvailable
            }
            
            /* Keyboard & Menu Shortcuts */
            else if menuItem.action == #selector(windowZoomInAction(_:)) {
                return sceneController.isAllowedToPerformMagnify
            }
            else if menuItem.action == #selector(windowZoomOutAction(_:)) {
                return sceneController.isAllowedToPerformMinify
            }
            else if menuItem.action == #selector(windowNavigateToAction(_:)) {
                return sceneController.isCursorMovableByKeyboard
            }
            
            /* Keyboard Shortcuts */
            else if menuItem.action == #selector(windowQuickAnnotatorAction(_:))
                        || menuItem.action == #selector(windowQuickCopyAnnotatorAction(_:))
                        || menuItem.action == #selector(windowRemoveAnnotatorAction(_:))
                        || menuItem.action == #selector(windowListRemovableAnnotatorAction(_:))
            {
                return sceneController.isAllowedToPerformCursorActions
            }
            else if menuItem.action == #selector(windowSelectPreviousAnnotatorAction(_:))
                        || menuItem.action == #selector(windowSelectNextAnnotatorAction(_:))
            {
                return sceneController.isAllowedToPerformCursorActions && sceneController.isOverlaySelectableByKeyboard
            }
            
            return true
        }
        else if menuItem.action == #selector(toggleCommandPalette(_:))
        {
            return true
        }
        return false
    }
    
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if item.itemIdentifier == .annotateItem
            || item.itemIdentifier == .selectItem
            || item.itemIdentifier == .magnifyItem
            || item.itemIdentifier == .minifyItem
            || item.itemIdentifier == .moveItem
            || item.itemIdentifier == .fitWindowItem
            || item.itemIdentifier == .fillWindowItem
            || item.itemIdentifier == .sceneToolGroup
            || item.itemIdentifier == .sceneActionGroup
            || item.action == #selector(touchBarOpenAction(_:))
            || item.action == #selector(touchBarSceneToolControlAction(_:))
            || item.action == #selector(touchBarSceneActionControlAction(_:))
        {  // when loaded
            return documentState.isLoaded
        }
        
        else if item.itemIdentifier == .openItem
            || item.action == #selector(touchBarOpenAction(_:))
        {  // not loaded or not restricted
            return documentState.isReadable || !documentState.isLoaded
        }

        else if item.itemIdentifier == .screenshotItem
            || item.action == #selector(touchBarScreenshotAction(_:))
        {
            return isScreenshotActionAllowed
        }

        return false
    }
    
}


// MARK: - Touch Bar Actions

extension WindowController {
    
    enum ToolIndex: Int {
        case magicCursor = 0
        case selectionArrow
        case magnifyingGlass
        case minifyingGlass
        case movingHand
    }

    enum ActionIndex: Int {
        case fitWindow = 0
        case fillWindow
    }
    
    private func syncToolbarState(_ sender: Any?) {
        let selectedSceneToolIdentifier = sceneToolsGroup.selectedItemIdentifier?.rawValue

        if selectedSceneToolIdentifier == SceneTool.magicCursor.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.magicCursor.rawValue
            splitController.useAnnotateItemAction(sender)
        }
        else if selectedSceneToolIdentifier == SceneTool.selectionArrow.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.selectionArrow.rawValue
            splitController.useSelectItemAction(sender)
        }
        else if selectedSceneToolIdentifier == SceneTool.magnifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.magnifyingGlass.rawValue
            splitController.useMagnifyItemAction(sender)
        }
        else if selectedSceneToolIdentifier == SceneTool.minifyingGlass.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.minifyingGlass.rawValue
            splitController.useMinifyItemAction(sender)
        }
        else if selectedSceneToolIdentifier == SceneTool.movingHand.rawValue {
            touchBarSceneToolControl.selectedSegment = ToolIndex.movingHand.rawValue
            splitController.useMoveItemAction(sender)
        }

        invalidateRestorableState()
    }
    
    @IBAction private func touchBarOpenAction(_ sender: Any?) {
        openAction(sender)
    }
    
    @IBAction private func touchBarSceneToolControlAction(_ sender: NSSegmentedControl) {
        guard documentState.isLoaded else {
            syncToolbarState(sender)
            return
        }
        if sender.selectedSegment == ToolIndex.magicCursor.rawValue {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.selectionArrow.rawValue {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.magnifyingGlass.rawValue {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.minifyingGlass.rawValue {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        }
        else if sender.selectedSegment == ToolIndex.movingHand.rawValue {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        }
        syncToolbarState(sender)
    }
    
    @IBAction private func touchBarSceneActionControlAction(_ sender: NSSegmentedControl) {
        guard documentState.isLoaded else { return }
        if sender.selectedSegment == ActionIndex.fitWindow.rawValue {
            splitController.fitWindowAction(sender)
        }
        else if sender.selectedSegment == ActionIndex.fillWindow.rawValue {
            splitController.fillWindowAction(sender)
        }
    }
    
    @IBAction private func touchBarScreenshotAction(_ sender: Any?) {
        screenshotAction(sender)
    }
    
    @IBAction private func previewSliderValueChanged(_ sender: NSSlider?) {
        guard let sender = sender else { return }
        let isPressed = !(NSEvent.pressedMouseButtons & 1 != 1)
        if isPressed {
            if previewStage == .none || previewStage == .end {
                previewStage = .begin
            } else if previewStage == .begin {
                previewStage = .inProgress
            }
        } else {
            if previewStage == .begin || previewStage == .inProgress {
                previewStage = .end
            } else if previewStage == .end {
                previewStage = .none
            }
        }
        previewAction(self, toMagnification: CGFloat(pow(2, sender.doubleValue)))
    }
    
}


// MARK: - Toolbar Actions

extension WindowController: SceneActionResponder, AnnotatorActionResponder {
    
    /* Scene Actions */
    
    @objc func openAction(_ sender: Any?) {
        guard documentState.isReadable || !documentState.isLoaded else { return }
        NSDocumentController.shared.openDocument(sender)
    }
    
    @objc func useAnnotateItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magicCursor.rawValue)
        syncToolbarState(sender)
    }
    
    @objc func useMagnifyItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.magnifyingGlass.rawValue)
        syncToolbarState(sender)
    }
    
    @objc func useMinifyItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.minifyingGlass.rawValue)
        syncToolbarState(sender)
    }
    
    @objc func useSelectItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.selectionArrow.rawValue)
        syncToolbarState(sender)
    }
    
    @objc func useMoveItemAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(SceneTool.movingHand.rawValue)
        syncToolbarState(sender)
    }
    
    @objc func fitWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.fitWindowAction(sender)
    }
    
    @objc func fillWindowAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.fillWindowAction(sender)
    }
    
    func zoomInAction(_ sender: Any?, centeringType center: SceneScrollView.ZoomingCenteringType) {
        guard documentState.isLoaded else { return }
        splitController.zoomInAction(sender, centeringType: center)
    }
    
    func zoomOutAction(_ sender: Any?, centeringType center: SceneScrollView.ZoomingCenteringType) {
        guard documentState.isLoaded else { return }
        splitController.zoomOutAction(sender, centeringType: center)
    }
    
    func zoomToAction(_ sender: Any?, value: CGFloat) {
        guard documentState.isLoaded else { return }
        splitController.zoomToAction(sender, value: value)
    }
    
    @objc func screenshotAction(_ sender: Any?) {
        guard documentState.isReadable || !documentState.isLoaded else { return }
        AppDelegate.shared.takeScreenshot(sender)
    }
    
    func navigateToAction(
        _ sender: Any?,
        direction: SceneScrollView.NavigationDirection,
        distance: SceneScrollView.NavigationDistance,
        centeringType center: SceneScrollView.NavigationCenteringType
    ) {
        guard documentState.isLoaded else { return }
        splitController.navigateToAction(
            sender,
            direction: direction,
            distance: distance,
            centeringType: center
        )
    }
    
    /* Annotator Actions (Local Notifications) */
    
    func quickAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.quickAnnotatorAction(sender)
    }
    
    func quickCopyAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.quickCopyAnnotatorAction(sender)
    }
    
    func selectPreviousAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.selectPreviousAnnotatorAction(sender)
    }
    
    func selectNextAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.selectNextAnnotatorAction(sender)
    }
    
    func removeAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.removeAnnotatorAction(sender)
    }
    
    func listRemovableAnnotatorAction(_ sender: Any?) {
        guard documentState.isLoaded else { return }
        splitController.listRemovableAnnotatorAction(sender)
    }
    
}


// MARK: - Interface Builder Actions

extension WindowController {
    
    /* Scene Actions */
    
    @IBAction private func windowUseAnnotateItemAction(_ sender: NSMenuItem) {
        useAnnotateItemAction(sender)
    }
    
    @IBAction private func windowUseMagnifyItemAction(_ sender: NSMenuItem) {
        useMagnifyItemAction(sender)
    }
    
    @IBAction private func windowUseMinifyItemAction(_ sender: NSMenuItem) {
        useMinifyItemAction(sender)
    }
    
    @IBAction private func windowUseSelectItemAction(_ sender: NSMenuItem) {
        useSelectItemAction(sender)
    }
    
    @IBAction private func windowUseMoveItemAction(_ sender: NSMenuItem) {
        useMoveItemAction(sender)
    }
    
    @IBAction private func windowFitWindowAction(_ sender: NSMenuItem) {
        fitWindowAction(sender)
    }
    
    @IBAction private func windowFillWindowAction(_ sender: NSMenuItem) {
        fillWindowAction(sender)
    }
    
    @IBAction private func windowZoomInAction(_ sender: NSMenuItem) {
        guard let eventType = window?.currentEvent?.type else { return }
        zoomInAction(sender, centeringType: eventType.isPointerType ? .imageCenter : .mouseLocation)
    }
    
    @IBAction private func windowZoomOutAction(_ sender: NSMenuItem) {
        guard let eventType = window?.currentEvent?.type else { return }
        zoomOutAction(sender, centeringType: eventType.isPointerType ? .imageCenter : .mouseLocation)
    }
    
    @IBAction private func windowZoomToAction(_ sender: NSMenuItem) {
        guard let ident = sender.identifier else { return }
        switch ident {
        case .zoomingLevel25:
            zoomToAction(sender, value: 0.25)
        case .zoomingLevel50:
            zoomToAction(sender, value: 0.5)
        case .zoomingLevel75:
            zoomToAction(sender, value: 0.75)
        case .zoomingLevel100:
            zoomToAction(sender, value: 1)
        case .zoomingLevel125:
            zoomToAction(sender, value: 1.25)
        case .zoomingLevel150:
            zoomToAction(sender, value: 1.5)
        case .zoomingLevel200:
            zoomToAction(sender, value: 2)
        case .zoomingLevel300:
            zoomToAction(sender, value: 3)
        case .zoomingLevel400:
            zoomToAction(sender, value: 4)
        case .zoomingLevel800:
            zoomToAction(sender, value: 8)
        case .zoomingLevel1600:
            zoomToAction(sender, value: 16)
        case .zoomingLevel3200:
            zoomToAction(sender, value: 32)
        case .zoomingLevel6400:
            zoomToAction(sender, value: 64)
        case .zoomingLevel12800:
            zoomToAction(sender, value: 128)
        case .zoomingLevel25600:
            zoomToAction(sender, value: 256)
        default:
            fatalError("unrecognized menu item")
        }
    }
    
    @IBAction private func windowNavigateToAction(_ sender: NSMenuItem) {
        guard let eventType = window?.currentEvent?.type,
              let ident = sender.identifier
        else { return }
        navigateToAction(
            sender,
            direction: SceneScrollView.NavigationDirection.direction(fromMenuItemIdentifier: ident),
            distance: SceneScrollView.NavigationDistance.distance(from: ident),
            centeringType: eventType.isPointerType ? .global : .fromMouseLocation
        )
    }
    
    @IBAction private func windowSetupSmartZoomAction(_ sender: NSMenuItem) {
        let toMagnification = sceneController.wrapperRestrictedMagnification
        UserDefaults.standard[.sceneMaximumSmartMagnification] = toMagnification
        let userAlert = NSAlert()
        userAlert.messageText = NSLocalizedString("Operation Succeed", comment: "windowSetupSmartZoomAction(_:)")
        userAlert.informativeText = String(format: NSLocalizedString("Successfully set maximum smart zoom magnification to a new value = %.2f", comment: "windowSetupSmartZoomAction(_:)"), toMagnification)
        showSheet(userAlert, completionHandler: nil)
    }
    
    /* Annotator Actions (Local Notifications) */
    
    @IBAction private func windowQuickAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        quickAnnotatorAction(sender)
    }
    
    @IBAction private func windowQuickCopyAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        quickCopyAnnotatorAction(sender)
    }
    
    @IBAction private func windowSelectPreviousAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        selectPreviousAnnotatorAction(sender)
    }
    
    @IBAction private func windowSelectNextAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        selectNextAnnotatorAction(sender)
    }
    
    @IBAction private func windowRemoveAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        removeAnnotatorAction(sender)
    }
    
    @IBAction private func windowListRemovableAnnotatorAction(_ sender: Any?) {
        guard let eventType = window?.currentEvent?.type,
              !eventType.isPointerType
        else { return }
        listRemovableAnnotatorAction(sender)
    }
    
}


// MARK: - NSWindowDelegate

extension WindowController: NSWindowDelegate {
    
    func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == self.window {
            GridWindowController.shared.activeWindowController = self
            tabDelegate.activeManagedWindow(windowController: self)
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == self.window {
            ShortcutGuideWindowController.shared.hide()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == NSColorPanel.shared, let window = window as? NSColorPanel {
            window.setTarget(nil)
            window.setAction(nil)
        }
    }
    
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        if let firstResponder = window.firstResponder as? UndoProxy {
            return firstResponder.undoManager
        }
        return nil
    }
    
}


// MARK: - NSToolbarDelegate, NSTouchBarDelegate

extension WindowController: NSToolbarDelegate, NSTouchBarDelegate {
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if toolbar == self.toolbar {
            return [
                .openItem,
                .sceneToolGroup,
                .sceneActionGroup,
                .screenshotItem,
                .sidebarTrackingSeparator,
                .sidebarItem,
                .space,
                .flexibleSpace,
            ]
        } else {
            return []
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        if toolbar == self.toolbar {
            return [
                .openItem,
                .sceneToolGroup,
                .sceneActionGroup,
                .sidebarTrackingSeparator,
                .sidebarItem,
                .flexibleSpace,
                .screenshotItem,
            ]
        } else {
            return []
        }
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if toolbar == self.toolbar {
            switch itemIdentifier {
            case .openItem:
                return openItem
            case .annotateItem:
                return annotateItem
            case .selectItem:
                return selectItem
            case .magnifyItem:
                return magnifyItem
            case .minifyItem:
                return minifyItem
            case .moveItem:
                return moveItem
            case .fitWindowItem:
                return fitWindowItem
            case .fillWindowItem:
                return fillWindowItem
            case .screenshotItem:
                return screenshotItem
            case .sidebarItem:
                return sidebarItem
            case .sidebarTrackingSeparator:
                return sidebarTrackingSeparatorItem
            case .sceneToolGroup:
                return sceneToolsGroup
            case .sceneActionGroup:
                return previewToolsGroup
            default:
                return nil
            }
        }
        return nil
    }
    
}


// MARK: - ScreenshotLoader

extension WindowController: ScreenshotLoader {
    
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        try splitController.load(screenshot)
        
        if let fileURL = screenshot.fileURL {
            self.updateWindowTitle(fileURL)
        }
        
        touchBarSceneToolControl.isEnabled = documentState.isLoaded
        touchBarSceneActionControl.isEnabled = documentState.isLoaded
        touchBarPreviewSlider.isEnabled = documentState.isLoaded

        documentObservations = [
            observe(\.screenshot?.fileURL, options: [.new]) { (target, change) in
                if let url = change.newValue as? URL {
                    target.updateWindowTitle(url)
                }
            }
        ]
    }
    
}


// MARK: - ItemPreviewDelegate

extension WindowController: ItemPreviewDelegate {
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if let title = window?.title {
            return title
        }
        return displayName
    }
    
    private var windowTitle: String {
        get { window?.title ?? ""      }
        set { window?.title = newValue }
    }

    @available(OSX 11.0, *)
    private var windowSubtitle: String {
        get { window?.subtitle ?? ""      }
        set {
            _windowSubtitle = newValue
            #if APP_STORE
            if PurchaseManager.shared.getProductType() == .subscribed {
                window?.subtitle = newValue
            } else {
                window?.subtitle = NSLocalizedString("Demo Version - ", comment: "PurchaseManager") + newValue
            }
            #else
            window?.subtitle = newValue
            #endif
        }
    }
    
    func updateWindowTitle(_ url: URL, magnification: CGFloat? = nil) {
        let magnification = magnification ?? lastStoredMagnification ?? 1.0
        if #available(macOS 11.0, *) {
            windowTitle = url.lastPathComponent
            windowSubtitle = "\(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        } else {
            windowTitle = "\(url.lastPathComponent) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
    }
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        GridWindowController.shared.sceneRawColorDidChange(sender, at: coordinate)
    }
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sender = sender else { return }
        let restrictedMagnification = sender.wrapperRestrictedMagnification
        if restrictedMagnification != lastStoredMagnification {
            lastStoredMagnification = restrictedMagnification
            if let url = screenshot?.fileURL {
                updateWindowTitle(url, magnification: restrictedMagnification)
            }
        }
        updatePreview(to: rect, magnification: restrictedMagnification)
    }
    
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?) {
        guard let rect = rect,
            let magnification = magnification else { return }
        updatePreview(to: rect, magnification: magnification)
    }
    
    func updatePreview(to rect: CGRect, magnification: CGFloat) {
        // guard touchBarPopoverItem.popoverTouchBar.isVisible else { return }
        touchBarPreviewSlider.doubleValue = Double(log2(magnification))
    }
    
}


// MARK: - ItemPreviewSender, ItemPreviewResponder

extension WindowController: ItemPreviewSender, ItemPreviewResponder {
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        splitController.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        splitController.previewAction(sender, atRelativePosition: position, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        splitController.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        splitController.previewAction(sender, toMagnification: magnification)
    }
    
    func previewActionRaw(_ sender: ItemPreviewSender?, withEvent event: NSEvent) {
        splitController.previewActionRaw(sender, withEvent: event)
    }
    
}

extension WindowController: ShortcutGuideDataSource {

    @IBAction private func toggleCommandPalette(_ sender: Any?) {
        guard let window = window else { return }
        let guideCtrl = ShortcutGuideWindowController.shared
        guideCtrl.loadItemsForWindow(window)
        guideCtrl.toggleForWindow(window, columnStyle: nil)
    }

    var shortcutItems: [ShortcutItem] {
        var items = [ShortcutItem]()
        if isScreenshotActionAllowed {
            items += [
                /* FIXED */
                ShortcutItem(
                    name: NSLocalizedString("Command Palette…", comment: "Shortcut Guide"),
                    toolTip: NSLocalizedString("Show a palette with available keyboard shortcuts.", comment: "Shortcut Guide"),
                    modifierFlags: [.command],
                    keyEquivalent: NSLocalizedString("Double Press", comment: "Shortcut Guide")
                ),
            ]
        }
        return items
    }

}


// MARK: - Restorable States

extension WindowController {

    private static let restorableToolbarSelectedState = "window.toolbar.selectedItemIdentifier"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(sceneToolsGroup.selectedItemIdentifier, forKey: WindowController.restorableToolbarSelectedState)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let window = window, let selectedItemIdentifier = coder.decodeObject(of: NSString.self, forKey: WindowController.restorableToolbarSelectedState)
        {
            sceneToolsGroup.selectedItemIdentifier = NSToolbarItem.Identifier(rawValue: NSToolbarItem.Identifier.RawValue(selectedItemIdentifier))
            syncToolbarState(window)
        }
    }
    
}


// MARK: - Subscription

extension WindowController {
    
    #if APP_STORE
    @objc private func productTypeDidChange(_ noti: Notification) {
        guard let manager = noti.object as? PurchaseManager else { return }
        if manager.getProductType() == .subscribed, let lastStoredSubtitle = _windowSubtitle {
            DispatchQueue.main.async {
                self.window?.subtitle = lastStoredSubtitle
            }
        }
    }
    #endif
    
}

