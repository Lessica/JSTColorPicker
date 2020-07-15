//
//  SplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class SplitController: NSSplitViewController {
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func viewDidLoad() {
        
        contentController.actionDelegate         = self
        sceneController.trackingDelegate         = self
        sceneController.contentDelegate          = self
        sidebarController.previewOverlayDelegate = self
        
        super.viewDidLoad()
        
        contentController.tagListSource    = tagListController
        sceneController.tagListSource      = tagListController
        tagListController.sceneToolSource  = sceneController
        tagListController.importItemSource = contentController
        tagListController.contentDelegate  = self
        
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    public weak var trackingObject       : SceneTracking!
    internal weak var screenshot         : Screenshot?
    
    private var documentObservations     : [NSKeyValueObservation]?
    private var lastStoredMagnification  : CGFloat?
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        sidebarController.ensureOverlayBounds(to: sceneController.wrapperRestrictedRect, magnification: sceneController.wrapperRestrictedMagnification)
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
}

extension SplitController: DropViewDelegate {
    
    private var contentController: ContentController! {
        return children[0] as? ContentController
    }
    
    private var sceneController: SceneController! {
        return children[1] as? SceneController
    }
    
    private var sidebarController: SidebarController! {
        return children[2] as? SidebarController
    }
    
    private var tagListController: TagListController! {
        return sidebarController.tagListController
    }
    
    private var windowTitle: String {
        get { view.window?.title ?? ""      }
        set { view.window?.title = newValue }
    }
    
    internal var allowsDrop: Bool {
        return true
    }
    
    internal var acceptedFileExtensions: [String] {
        return ["png"]
    }
    
    func dropView(_: DropSplitView?, didDropFileWith fileURL: NSURL) {
        NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: view.window)
        let documentController = NSDocumentController.shared
        documentController.openDocument(withContentsOf: fileURL as URL, display: true) { [weak self] (document, documentWasAlreadyOpen, error) in
            NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: nil)
            if let error = error {
                self?.presentError(error)
            }
        }
    }
    
}

extension SplitController: SceneTracking {
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        guard let color = image.color(at: coordinate) else { return }
        sidebarController.inspectItem(color, shouldSubmit: false)
        trackingObject.sceneRawColorDidChange(sender, at: coordinate)
    }
    
    func sceneRawAreaDidChange(_ sender: SceneScrollView?, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        guard let area = image.area(at: rect) else { return }
        sidebarController.inspectItem(area, shouldSubmit: false)
    }
    
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        guard let sender = sender else { return }
        
        let restrictedMagnification = max(min(magnification, sender.maxMagnification), sender.minMagnification)
        sidebarController.updatePreview(to: rect, magnification: restrictedMagnification)
        
        if restrictedMagnification != lastStoredMagnification {
            lastStoredMagnification = restrictedMagnification
            if let url = screenshot?.fileURL {
                updateWindowTitle(url, magnification: restrictedMagnification)
            }
        }
    }
    
}

extension SplitController: ToolbarResponder {
    
    func useAnnotateItemAction(_ sender: Any?) {
        sceneController.useAnnotateItemAction(sender)
    }
    
    func useMagnifyItemAction(_ sender: Any?) {
        sceneController.useMagnifyItemAction(sender)
    }
    
    func useMinifyItemAction(_ sender: Any?) {
        sceneController.useMinifyItemAction(sender)
    }
    
    func useSelectItemAction(_ sender: Any?) {
        sceneController.useSelectItemAction(sender)
    }
    
    func useMoveItemAction(_ sender: Any?) {
        sceneController.useMoveItemAction(sender)
    }
    
    func fitWindowAction(_ sender: Any?) {
        sceneController.fitWindowAction(sender)
    }
    
    func fillWindowAction(_ sender: Any?) {
        sceneController.fillWindowAction(sender)
    }
    
}

extension SplitController: ScreenshotLoader {
    
    func load(_ screenshot: Screenshot) throws {
        
        self.screenshot = screenshot
        do {
            try contentController.load(screenshot)
            try sceneController.load(screenshot)
            try sidebarController.load(screenshot)
        } catch {
            if let _ = screenshot.fileURL {
                presentError(error)
            }
        }
        
        if let fileURL = screenshot.fileURL {
            self.updateWindowTitle(fileURL)
        }
        documentObservations = [
            screenshot.observe(\.fileURL, options: [.new]) { [unowned self] (_, change) in
                if let url = change.newValue as? URL {
                    if let restrictedMagnification = self.lastStoredMagnification {
                        self.updateWindowTitle(url, magnification: restrictedMagnification)
                    } else {
                        self.updateWindowTitle(url)
                    }
                }
            }
        ]
        
    }
    
    func updateWindowTitle(_ url: URL, magnification: CGFloat? = 1.0) {
        if let magnification = magnification {
            windowTitle = "\(url.lastPathComponent) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        } else {
            windowTitle = url.lastPathComponent
        }
    }
    
}

extension SplitController: ContentDelegate {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: coordinate)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: rect)
        } catch Content.Error.userAborted {
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
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool) throws -> ContentItem? {
        do {
            return try contentController.selectContentItem(item, byExtendingSelection: extend)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool) throws -> [ContentItem]? {
        do {
            return try contentController.selectContentItems(items, byExtendingSelection: extend)
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
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(of: coordinate)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(item)
        } catch Content.Error.userAborted {
            return nil
        } catch {
            presentError(error)
        }
        return nil
    }
    
    func deselectAllContentItems() {
        contentController.deselectAllContentItems()
    }
    
}

extension SplitController: ContentActionDelegate {
    
    private func contentItemChanged(_ item: ContentItem) {
        if let item = item as? PixelColor {
            trackingObject.sceneRawColorDidChange(nil, at: item.coordinate)
        }
        else if let item = item as? PixelArea {
            trackingObject.sceneRawAreaDidChange(nil, to: item.rect)
        }
    }
    
    func contentActionAdded(_ items: [ContentItem]) {
        sceneController.addAnnotators(for: items)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.inspectItem(item, shouldSubmit: true)
        }
    }
    
    func contentActionUpdated(_ items: [ContentItem]) {
        sceneController.updateAnnotator(for: items)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.inspectItem(item, shouldSubmit: true)
        }
    }
    
    func contentActionSelected(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        tagListController.previewTags(for: items)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.inspectItem(item, shouldSubmit: true)
        }
    }
    
    func contentActionConfirmed(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // with scroll
        tagListController.previewTags(for: items)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.inspectItem(item, shouldSubmit: true)
        }
    }
    
    func contentActionDeleted(_ items: [ContentItem]) {
        sceneController.removeAnnotators(for: items)
    }
    
}

extension SplitController: ItemPreviewResponder {
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool) {
        sceneController.previewAction(sender, toMagnification: magnification, isChanging: isChanging)
    }
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        sceneController.previewAction(sender, centeredAt: coordinate)
    }
    
}

extension SplitController: PixelMatchResponder {
    
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        sceneController.beginPixelMatchComparison(to: image, with: maskImage, completionHandler: completionHandler)
        sidebarController.beginPixelMatchComparison(to: image, with: maskImage, completionHandler: completionHandler)
    }
    
    func endPixelMatchComparison() {
        sceneController.endPixelMatchComparison()
        sidebarController.endPixelMatchComparison()
    }
    
}

