//
//  SplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

class SplitController: NSSplitViewController {

    enum ArrangedIndex: Int {
        case content = 0
        case scene
        case sidebar
    }

    private func arrangedSubview(at index: ArrangedIndex) -> NSView {
        return splitView.arrangedSubviews[index.rawValue]
    }

    func isSubviewCollapsed(at index: ArrangedIndex) -> Bool {
        return splitView.isSubviewCollapsed(arrangedSubview(at: index))
    }

    public  weak var parentTracking             : SceneTracking?
    private weak var sceneToolSource            : SceneToolSource!
    
    override func viewDidLoad() {
        contentController.actionManager          = self
        sceneController.parentTracking           = self
        sceneController.contentManager           = self
        
        super.viewDidLoad()
        
        contentController.tagManager       = tagListController
        sceneController.tagManager         = tagListController
        sceneToolSource                    = sceneController
        previewController.overlayDelegate  = self
        tagListController.sceneToolSource  = sceneController
        tagListController.importSource     = contentController
        tagListController.contentManager   = self
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    internal weak var screenshot                : Screenshot?
    private var documentState                   : Screenshot.State { screenshot?.state ?? .notLoaded }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        var previewDelegates: [ItemPreviewDelegate] = [
            previewController,
        ]
        if let previewParent = parentTracking as? ItemPreviewDelegate {
            previewDelegates.append(previewParent)
        }
        previewDelegates.forEach(
            { $0.ensureOverlayBounds(to: sceneController.wrapperRestrictedRect, magnification: sceneController.wrapperRestrictedMagnification) }
        )
    }
    
}

extension SplitController: PaneContainer {
    
    var contentController        : ContentController!       { children.first(where: { $0 is ContentController }) as? ContentController }
    var sceneController          : SceneController!         { children.first(where: { $0 is SceneController   }) as? SceneController   }
    var segmentController        : SegmentController!       { children.first(where: { $0 is SegmentController }) as? SegmentController }
    
    var childPaneContainers      : [PaneContainer]          { children.compactMap(  { $0 as? PaneContainer  }  ) }
    var paneControllers          : [PaneController]         { children.compactMap(  { $0 as? PaneController }  ) }
    
    private var descendantPaneContainers   : [PaneContainer]
    {
        var childContainers = [NSViewController]()
        var allContainers = [NSViewController](arrayLiteral: self)
        while let lastContainer = allContainers.popLast() {
            childContainers.append(lastContainer)
            allContainers.insert(contentsOf: lastContainer.children.compactMap({ $0 as? PaneContainer }) as! [NSViewController], at: 0)
        }
        return Array(childContainers.dropFirst()) as! [PaneContainer]
    }
    
    private var descendantPaneControllers  : [PaneController]
    {
        paneControllers + descendantPaneContainers.flatMap({ $0.paneControllers })
    }
    
    var documentStackedController  : DocumentStackedController!  { descendantPaneContainers .compactMap({ $0 as? DocumentStackedController  }).first! }
    var previewController          : PreviewController!          { descendantPaneControllers.compactMap({ $0 as? PreviewController          }).first! }
    var tagListController          : TagListController!          { descendantPaneControllers.compactMap({ $0 as? TagListController          }).first! }
    
    func inspectorController(_ style: InspectorController.Style) -> InspectorController {
        return descendantPaneControllers
            .compactMap({ $0 as? InspectorController })
            .filter({ $0.style == style })
            .first!
    }

    func focusPane(menuIdentifier identifier: NSUserInterfaceItemIdentifier, completionHandler completion: @escaping (PaneContainer) -> Void) {
        childPaneContainers.forEach(
            { $0.focusPane(menuIdentifier: identifier, completionHandler: completion) }
        )
    }

    @IBAction func focusPane(_ sender: NSMenuItem) {
        focusPane(menuIdentifier: sender.identifier!) { [unowned self] (sender) in
            if self.isSubviewCollapsed(at: .sidebar) {
                self.toggleSidebar(sender)
            }
        }
    }
}

extension SplitController: DropViewDelegate {

    var allowsDrop: Bool {
        return true
    }
    
    var acceptedFileExtensions: [String] {
        return ["png", "jpg", "jpeg"]
    }
    
    func dropView(_: DropSplitView?, didDropFilesWith fileURLs: [URL]) {
        guard fileURLs.count > 0 else { return }
        NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: view.window)
        let documentController = NSDocumentController.shared
        if fileURLs.count == 1, let fileURL = fileURLs.first {
            documentController.openDocument(
                withContentsOf: fileURL,
                display: true
            ) { [weak self] (document, documentWasAlreadyOpen, error) in
                NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: nil)
                if let error = error {
                    self?.presentError(error)
                }
            }
        } else {
            let window = view.window
            DispatchQueue.global(qos: .userInitiated).async {
                var errors = [Swift.Error]()
                let group = DispatchGroup()
                group.notify(queue: .main) {
                    NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: nil)
                    if !errors.isEmpty {
                        debugPrint("\(errors)")
                    }
                }
                let sema = DispatchSemaphore(value: fileURLs.count)
                for (fileIndex, fileURL) in fileURLs.enumerated() {
                    if fileIndex == 0 {
                        NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: window)
                    }
                    group.enter()
                    documentController.openDocument(
                        withContentsOf: fileURL,
                        display: true
                    ) { (document, documentWasAlreadyOpen, error) in
                        if let error = error {
                            debugPrint(error)
                            errors.append(error)
                        } else {
                            debugPrint("\(String(describing: document)), wasAlreadyOpen = \(documentWasAlreadyOpen)")
                        }
                        sema.signal()
                        group.leave()
                    }
                }
                sema.wait()
            }
        }
    }
    
}

extension SplitController: SceneTracking {
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        guard let color = image.color(at: coordinate) else { return }
        inspectorController(.primary).inspectItem(color)
        parentTracking?.sceneRawColorDidChange(sender, at: coordinate)
    }
    
    func sceneRawAreaDidChange(_ sender: SceneScrollView?, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        guard let area = image.area(at: rect) else { return }
        inspectorController(.primary).inspectItem(area)
        parentTracking?.sceneRawAreaDidChange(sender, to: rect)
    }
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sender = sender else { return }
        var sceneTrackings: [SceneTracking] = [
            previewController,
        ]
        if parentTracking != nil {
            sceneTrackings.append(parentTracking!)
        }
        sceneTrackings.forEach({ $0.sceneVisibleRectDidChange(sender, to: rect, of: magnification) })
    }
    
}

extension SplitController: ToolbarResponder {
    func useAnnotateItemAction(_ sender: Any?) { sceneController.useAnnotateItemAction(sender) }
    func useMagnifyItemAction(_ sender: Any?)  { sceneController.useMagnifyItemAction(sender)  }
    func useMinifyItemAction(_ sender: Any?)   { sceneController.useMinifyItemAction(sender)   }
    func useSelectItemAction(_ sender: Any?)   { sceneController.useSelectItemAction(sender)   }
    func useMoveItemAction(_ sender: Any?)     { sceneController.useMoveItemAction(sender)     }
    func fitWindowAction(_ sender: Any?)       { sceneController.fitWindowAction(sender)       }
    func fillWindowAction(_ sender: Any?)      { sceneController.fillWindowAction(sender)      }
}

extension SplitController: ScreenshotLoader {

    private var childScreenshotLoaders: [ScreenshotLoader] {
        var loaders: [ScreenshotLoader] = [
            contentController,
            sceneController,
        ]
        loaders += descendantPaneContainers
        loaders += descendantPaneControllers
        return loaders
    }
    
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        do {
            try childScreenshotLoaders.forEach({ try $0.load(screenshot) })
        } catch {
            if let _ = screenshot.fileURL {
                presentError(error)
            }
        }
    }
    
}

extension SplitController: ContentDelegate {
    
    func addContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: coordinate, byIgnoringPopups: ignore)
        } catch Content.Error.userAborted {
            return nil
        } catch Content.Error.itemExists where ignore {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func addContentItem(of rect: PixelRect, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: rect, byIgnoringPopups: ignore)
        } catch Content.Error.userAborted {
            return nil
        } catch Content.Error.itemExists where ignore {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        do {
            return try contentController.updateContentItem(item, to: rect)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.updateContentItem(item, to: coordinate)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItem(_ item: ContentItem) throws -> ContentItem? {
        do {
            return try contentController.updateContentItem(item)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItems(_ items: [ContentItem]) throws -> [ContentItem]? {
        do {
            return try contentController.updateContentItems(items)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> ContentItem? {
        do {
            return try contentController.selectContentItem(item, byExtendingSelection: extend, byFocusingSelection: focus)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> [ContentItem]? {
        do {
            return try contentController.selectContentItems(items, byExtendingSelection: extend, byFocusingSelection: focus)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem? {
        do {
            return try contentController.deselectContentItem(item)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(of: coordinate, byIgnoringPopups: ignore)
        } catch Content.Error.userAborted {
            return nil
        } catch Content.Error.itemDoesNotExist where ignore {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deleteContentItem(_ item: ContentItem, byIgnoringPopups ignore: Bool) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(item, byIgnoringPopups: ignore)
        } catch Content.Error.userAborted {
            return nil
        } catch Content.Error.itemDoesNotExist where ignore {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deselectAllContentItems() {
        contentController.deselectAllContentItems()
    }

    func copyContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.copyContentItem(of: coordinate)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
}

extension SplitController: ContentActionDelegate {
    
    private func contentItemChanged(_ item: ContentItem) {
        if let item = item as? PixelColor {
            parentTracking?.sceneRawColorDidChange(nil, at: item.coordinate)
        }
        else if let item = item as? PixelArea {
            parentTracking?.sceneRawAreaDidChange(nil, to: item.rect)
        }
    }
    
    func contentActionAdded(_ items: [ContentItem]) {
        sceneController.addAnnotators(for: items)
        if let item = items.first {
            contentItemChanged(item)
            inspectorController(.secondary).inspectItem(item)
        }
    }
    
    func contentActionUpdated(_ items: [ContentItem]) {
        sceneController.updateAnnotator(for: items)
        if let item = items.first {
            contentItemChanged(item)
            inspectorController(.secondary).inspectItem(item)
        }
    }
    
    func contentActionSelected(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        tagListController.previewTags(for: items)
        if let item = items.first {
            contentItemChanged(item)
            inspectorController(.secondary).inspectItem(item)
        }
    }
    
    func contentActionConfirmed(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // with scroll
        tagListController.previewTags(for: items)
        if let item = items.first {
            contentItemChanged(item)
            inspectorController(.secondary).inspectItem(item)
        }
    }
    
    func contentActionDeleted(_ items: [ContentItem]) {
        sceneController.removeAnnotators(for: items)
    }
    
}

extension SplitController: ItemPreviewResponder {
    
    func previewAction(_ sender: ItemPreviewSender?, toMagnification magnification: CGFloat) {
        sceneController.previewAction(sender, toMagnification: magnification)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atAbsolutePoint point: CGPoint, animated: Bool) {
        sceneController.previewAction(sender, atAbsolutePoint: point, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atRelativePosition position: CGSize, animated: Bool) {
        sceneController.previewAction(sender, atRelativePosition: position, animated: animated)
    }
    
    func previewAction(_ sender: ItemPreviewSender?, atCoordinate coordinate: PixelCoordinate, animated: Bool) {
        sceneController.previewAction(sender, atCoordinate: coordinate, animated: animated)
    }
    
}

extension SplitController: PixelMatchResponder {

    var childPixelMatchResponders: [PixelMatchResponder] { [
        sceneController,
        documentStackedController,
    ] }
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        childPixelMatchResponders.forEach({ $0.beginPixelMatchComparison(to: image, with: maskImage, completionHandler: completionHandler) })
    }
    
    func endPixelMatchComparison() {
        childPixelMatchResponders.forEach({ $0.endPixelMatchComparison() })
    }
    
}

extension SplitController: ShortcutGuideDataSource {

    var shortcutItems: [ShortcutItem] {
        var items = [ShortcutItem]()

        if documentState.isLoaded {
            switch sceneToolSource.sceneTool {
            case .magicCursor:
                if documentState.isWriteable {
                    items += [
                        ShortcutItem(
                            name: NSLocalizedString("Add Color & Coordinates Annotation", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Add Color & Coordinates at current cursor position to content list.", comment: "Shortcut Guide"),
                            modifierFlags: []
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("Add Color & Coordinates Annotation", comment: "Shortcut Guide"),
                            keyString: .return,
                            toolTip: NSLocalizedString("Add Color & Coordinates at current cursor position to content list.", comment: "Shortcut Guide"),
                            modifierFlags: [.command]
                        ),
                    ]
                    if sceneController.enableForceTouch {
                        items += [
                            ShortcutItem(
                                name: NSLocalizedString("Add Area Annotation", comment: "Shortcut Guide"),
                                keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                                toolTip: NSLocalizedString("Add Area at current dragged rectangle to content list.", comment: "Shortcut Guide"),
                                modifierFlags: []
                            ),
                            ShortcutItem(
                                name: NSLocalizedString("Add Area Annotation (Square)", comment: "Shortcut Guide"),
                                keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                                toolTip: NSLocalizedString("Add Area at current dragged square to content list.", comment: "Shortcut Guide"),
                                modifierFlags: [.shift]
                            ),
                        ]
                    } else {
                        items += [
                            ShortcutItem(
                                name: NSLocalizedString("Add Area Annotation", comment: "Shortcut Guide"),
                                keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                                toolTip: NSLocalizedString("Add Area at current dragged rectangle to content list.", comment: "Shortcut Guide"),
                                modifierFlags: [.shift]
                            ),
                        ]
                    }
                    items += [
                        ShortcutItem(
                            name: NSLocalizedString("Add Area Annotation (Centered)", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Add Area using the starting point as the midpoint of current dragged rectangle, to content list.", comment: "Shortcut Guide"),
                            modifierFlags: [.option]
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("Delete Annotation", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Right Click", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Delete Color & Coordinates at current cursor position or the top most Area contains current cursor position.", comment: "Shortcut Guide"),
                            modifierFlags: []
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("List Deletable Annotations", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Right Click", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Display a menu with all annotations cascading under the current cursor position, select one to delete the annotation.", comment: "Shortcut Guide"),
                            modifierFlags: [.option]
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("Delete Annotation", comment: "Shortcut Guide"),
                            keyString: .delete,
                            toolTip: NSLocalizedString("Delete Color & Coordinates at current cursor position or the top most Area contains current cursor position.", comment: "Shortcut Guide"),
                            modifierFlags: [.command]
                        ),
                    ]
                }
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("[Selection Arrow]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Selection Arrow temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.control]
                    ),
                ]
            case .selectionArrow:
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Select Annotation", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Select Color & Coordinates at current cursor position or the top most Area contains current cursor position.", comment: "Shortcut Guide"),
                        modifierFlags: []
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Select More Annotations", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Select Color & Coordinates at current cursor position or the top most Area contains current cursor position, while keeping the previous selections.", comment: "Shortcut Guide"),
                        modifierFlags: [.command]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Select All Cascaded Annotations", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Select Color & Coordinates at current cursor position or all Areas contains current cursor position, while keeping the previous selections.", comment: "Shortcut Guide"),
                        modifierFlags: [.shift]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("List All Cascaded Annotations", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Display a menu with all annotations cascading under the current cursor position, select one to select the annotation, while keeping the previous selections.", comment: "Shortcut Guide"),
                        modifierFlags: [.option]
                    ),
                ]
                if documentState.isWriteable {
                    items += [
                        ShortcutItem(
                            name: NSLocalizedString("Delete Annotation", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Right Click", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Delete Color & Coordinates at current cursor position or the top most Area contains current cursor position.", comment: "Shortcut Guide"),
                            modifierFlags: []
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("List Deletable Annotations", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Right Click", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Display a menu with all annotations cascading under the current cursor position, select one to delete the annotation.", comment: "Shortcut Guide"),
                            modifierFlags: [.option]
                        ),
                        ShortcutItem(
                            name: NSLocalizedString("Modify Annotation", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Drag Anchors", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Modify Color & Coordinates to a new position, or modify Area to a new dimension.", comment: "Shortcut Guide"),
                            modifierFlags: []
                        ),
                    ]
                    items += [
                        ShortcutItem(
                            name: NSLocalizedString("Modify Annotation (Fixed Ratio)", comment: "Shortcut Guide"),
                            keyString: NSLocalizedString("Drag Anchors in Corner", comment: "Shortcut Guide"),
                            toolTip: NSLocalizedString("Modify Area to a new dimension with its original ratio.", comment: "Shortcut Guide"),
                            modifierFlags: [.shift]
                        ),
                    ]
                }
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("[Magic Cursor]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Magic Cursor temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.control]
                    ),
                ]
            case .magnifyingGlass:
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Magnify", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Magnify to next level from current cursor position.", comment: "Shortcut Guide"),
                        modifierFlags: []
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Magnify To Fill Window", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Magnify to fill window with dragged area.", comment: "Shortcut Guide"),
                        modifierFlags: [.shift]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("[Magic Cursor]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Magic Cursor temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.control]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("[Minifying Glass]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Minifying Glass temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.option]
                    ),
                ]
            case .minifyingGlass:
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Minify", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Click", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Minify to previous level from current cursor position.", comment: "Shortcut Guide"),
                        modifierFlags: []
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("[Magic Cursor]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Magic Cursor temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.control]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("[Magnifying Glass]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Magnifying Glass temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.option]
                    ),
                ]
            case .movingHand:
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Move", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Drag", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("A simple drag-to-move operation for pointer devices.", comment: "Shortcut Guide"),
                        modifierFlags: []
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("[Magic Cursor]", comment: "Shortcut Guide"),
                        keyString: NSLocalizedString("Hold", comment: "Shortcut Guide"),
                        toolTip: NSLocalizedString("Switch to Magic Cursor temporarily.", comment: "Shortcut Guide"),
                        modifierFlags: [.control]
                    ),
                ]
            default:
                break
            }

            items += [
                ShortcutItem(
                    name: NSLocalizedString("Zoom Out", comment: "Shortcut Guide"),
                    keyString: "-",
                    toolTip: NSLocalizedString("Zoom out with the current cursor position (if the cursor is outside the scene, the scene is zoomed out with the center point).", comment: "Shortcut Guide"),
                    modifierFlags: [.command]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Zoom In", comment: "Shortcut Guide"),
                    keyString: "=",
                    toolTip: NSLocalizedString("Zoom in with the current cursor position (if the cursor is outside the scene, the scene is zoomed in with the center point).", comment: "Shortcut Guide"),
                    modifierFlags: [.command]
                ),
                ShortcutItem(
                    name: NSLocalizedString("Copy Color & Coordinates", comment: "Shortcut Guide"),
                    keyString: "`",
                    toolTip: NSLocalizedString("Copy the Color & Coordinates at the cursor location directly to the general pasteboard.", comment: "Shortcut Guide"),
                    modifierFlags: [.command]
                ),
            ]

            if sceneController.isCursorMovableByKeyboard {
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Move Cursor (1 pixel)", comment: "Shortcut Guide"),
                        keyString: [ShortcutItem.KeyboardCharacter](arrayLiteral: .up, .left, .down, .right).map({ $0.rawValue }).joined(separator: "/"),
                        toolTip: NSLocalizedString("Move cursor with keyboard by 1 pixel.", comment: "Shortcut Guide"),
                        modifierFlags: [.command]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Move Cursor (10 pixel)", comment: "Shortcut Guide"),
                        keyString: [ShortcutItem.KeyboardCharacter](arrayLiteral: .up, .left, .down, .right).map({ $0.rawValue }).joined(separator: "/"),
                        toolTip: NSLocalizedString("Move cursor with keyboard by 10 pixel.", comment: "Shortcut Guide"),
                        modifierFlags: [.shift, .command]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Move Cursor (100 pixel)", comment: "Shortcut Guide"),
                        keyString: [ShortcutItem.KeyboardCharacter](arrayLiteral: .up, .left, .down, .right).map({ $0.rawValue }).joined(separator: "/"),
                        toolTip: NSLocalizedString("Move cursor with keyboard by 100 pixel.", comment: "Shortcut Guide"),
                        modifierFlags: [.control, .command]
                    ),
                ]
            }

            if sceneController.isOverlaySelectableByKeyboard {
                items += [
                    ShortcutItem(
                        name: NSLocalizedString("Select Previous Annotation", comment: "Shortcut Guide"),
                        keyString: "[",
                        toolTip: NSLocalizedString("If the selected annotation is the only selected annotation in all levels under the current cursor position, the selected state is switched to the previous annotation in the cascade under the current cursor position.", comment: "Shortcut Guide"),
                        modifierFlags: [.command]
                    ),
                    ShortcutItem(
                        name: NSLocalizedString("Select Next Annotation", comment: "Shortcut Guide"),
                        keyString: "]",
                        toolTip: NSLocalizedString("If the selected annotation is the only selected annotation in all levels under the current cursor position, the selected state is switched to the next annotation in the cascade under the current cursor position.", comment: "Shortcut Guide"),
                        modifierFlags: [.command]
                    ),
                ]
            }
        }

        return items
    }

}

