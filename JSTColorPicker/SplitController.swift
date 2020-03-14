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
        contentController.actionDelegate = self
        sceneController.trackingDelegate = self
        sceneController.contentResponder = self
        sidebarController.previewOverlayDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeController()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    weak var trackingObject: SceneTracking?
    internal weak var screenshot: Screenshot?
    
    deinit {
        debugPrint("- [SplitController deinit]")
    }
    
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        sidebarController.ensureOverlayBounds(to: sceneController.wrapperVisibleBounds, magnification: sceneController.wrapperMagnification)
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
}

extension SplitController: DropViewDelegate {
    
    fileprivate var contentController: ContentController! {
        return children[0] as? ContentController
    }
    
    fileprivate var sceneController: SceneController! {
        return children[1] as? SceneController
    }
    
    fileprivate var sidebarController: SidebarController! {
        return children[2] as? SidebarController
    }
    
    fileprivate var windowTitle: String {
        get {
            return view.window?.title ?? ""
        }
        set {
            view.window?.title = newValue
        }
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
        documentController.openDocument(withContentsOf: fileURL as URL, display: true) { [unowned self] (document, documentWasAlreadyOpen, error) in
            NotificationCenter.default.post(name: .dropRespondingWindowChanged, object: nil)
            if let error = error {
                self.presentError(error)
            }
        }
    }
    
}

extension SplitController: SceneTracking {
    
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        guard let color = image.color(at: coordinate) else { return }
        sidebarController.updateItemInspector(for: color, submit: false)
        trackingObject?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: SceneScrollView?, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        guard let area = image.area(at: rect) else { return }
        sidebarController.updateItemInspector(for: area, submit: false)
    }
    
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) {
        if let title = screenshot?.fileURL?.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        sidebarController.updatePreview(to: rect, magnification: magnification)
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
    
    func initializeController() {
        
    }
    
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        do {
            try contentController.load(screenshot)
            try sceneController.load(screenshot)
            try sidebarController.load(screenshot)
        } catch let error {
            if let _ = screenshot.fileURL {
                presentError(error)
            }
        }
    }
    
}

extension SplitController: ContentResponder {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: coordinate)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func addContentItem(of rect: PixelRect) throws -> ContentItem? {
        do {
            return try contentController.addContentItem(of: rect)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem? {
        do {
            return try contentController.updateContentItem(item, to: rect)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.updateContentItem(item, to: coordinate)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func selectContentItem(_ item: ContentItem?) throws -> ContentItem? {
        do {
            return try contentController.selectContentItem(item)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(of: coordinate)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem? {
        do {
            return try contentController.deleteContentItem(item)
        } catch let error {
            presentError(error)
        }
        return nil
    }
    
}

extension SplitController: ContentActionDelegate {
    
    fileprivate func contentItemChanged(_ item: ContentItem) {
        if let item = item as? PixelColor {
            trackingObject?.trackColorChanged(nil, at: item.coordinate)
        }
        else if let item = item as? PixelArea {
            trackingObject?.trackAreaChanged(nil, to: item.rect)
        }
    }
    
    func contentActionAdded(_ items: [ContentItem]) {
        sceneController.addAnnotators(for: items)
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionUpdated(_ items: [ContentItem]) {
        sceneController.updateAnnotator(for: items)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionSelected(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionConfirmed(_ items: [ContentItem]) {
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // scroll
        if let item = items.first {
            contentItemChanged(item)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionDeleted(_ items: [ContentItem]) {
        sceneController.removeAnnotators(for: items)
    }
    
}

extension SplitController: PreviewResponder {
    
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

