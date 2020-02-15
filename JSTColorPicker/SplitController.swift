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
        sidebarController.ensureOverlayBounds(to: sceneController.sceneVisibleBounds, magnification: sceneController.sceneMagnification)
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
        NotificationCenter.default.post(name: .respondingWindowChanged, object: view.window)
        let documentController = NSDocumentController.shared
        documentController.openDocument(withContentsOf: fileURL as URL, display: true) { [unowned self] (document, documentWasAlreadyOpen, error) in
            NotificationCenter.default.post(name: .respondingWindowChanged, object: nil)
            if let error = error {
                self.presentError(error)
            }
        }
    }
    
}

extension SplitController: SceneTracking {
    
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        guard let color = image.color(at: coordinate) else { return }
        sidebarController.updateItemInspector(for: color, submit: false)
        trackingObject?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: Any, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        guard let area = image.area(at: rect) else { return }
        sidebarController.updateItemInspector(for: area, submit: false)
    }
    
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) {
        if let title = screenshot?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        sidebarController.updatePreview(to: rect, magnification: magnification)
    }
    
}

extension SplitController: ToolbarResponder {
    
    func useCursorAction(_ sender: Any?) {
        sceneController.useCursorAction(sender)
    }
    
    func useMagnifyToolAction(_ sender: Any?) {
        sceneController.useMagnifyToolAction(sender)
    }
    
    func useMinifyToolAction(_ sender: Any?) {
        sceneController.useMinifyToolAction(sender)
    }
    
    func useMoveToolAction(_ sender: Any?) {
        sceneController.useMoveToolAction(sender)
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
        contentController.initializeController()
        sceneController.initializeController()
        sidebarController.initializeController()
    }
    
    func load(_ screenshot: Screenshot) throws {
        initializeController()
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
            trackingObject?.trackColorChanged(self, at: item.coordinate)
        }
        else if let item = item as? PixelArea {
            trackingObject?.trackAreaChanged(self, to: item.rect)
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
    
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat) {
        sceneController.previewAction(sender, toMagnification: magnification)
    }
    
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate) {
        sceneController.previewAction(sender, centeredAt: coordinate)
    }
    
}

