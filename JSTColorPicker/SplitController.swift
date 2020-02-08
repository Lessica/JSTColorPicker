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
        sceneController.trackingObject = self
        sidebarController.previewOverlayDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetController()
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
        documentController.openDocument(withContentsOf: fileURL as URL, display: true) { (document, documentWasAlreadyOpen, error) in
            NotificationCenter.default.post(name: .respondingWindowChanged, object: nil)
            if let error = error {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
    
}

extension SplitController: SceneTracking {
    
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        sidebarController.updateItemInspector(for: image.color(at: coordinate), submit: false)
        trackingObject?.trackColorChanged(sender, at: coordinate)
    }
    
    func trackAreaChanged(_ sender: Any, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        sidebarController.updateItemInspector(for: image.area(at: rect), submit: false)
        trackingObject?.trackAreaChanged(sender, to: rect)
    }
    
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        let color = image.color(at: coordinate)
        sidebarController.updateItemInspector(for: color, submit: true)
        do {
            _ = try contentController.submitItem(color)
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) {
        guard let image = screenshot?.image else { return }
        let area = image.area(at: rect)
        do {
            _ = try contentController.submitItem(area)
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        do {
            _ = try contentController.deleteItem(at: coordinate)
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) {
        if let title = screenshot?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        sidebarController.updatePreview(to: rect, magnification: magnification)
        trackingObject?.trackSceneBoundsChanged(sender, to: rect, of: magnification)
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
    
    func resetController() {
        contentController.resetController()
        sceneController.resetController()
        sidebarController.resetController()
    }
    
    func load(_ screenshot: Screenshot) throws {
        resetController()
        self.screenshot = screenshot
        do {
            try contentController.load(screenshot)
            try sceneController.load(screenshot)
            try sidebarController.load(screenshot)
        } catch let error {
            if let _ = screenshot.fileURL {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
    
}

extension SplitController: ContentActionDelegate {
    
    fileprivate func contentItemChanged(_ item: ContentItem, by controller: ContentController) {
        if let item = item as? PixelColor {
            trackingObject?.trackColorChanged(controller, at: item.coordinate)
        }
        else if let item = item as? PixelArea {
            trackingObject?.trackAreaChanged(controller, to: item.rect)
        }
    }
    
    func contentActionAdded(_ items: [ContentItem], by controller: ContentController) {
        sceneController.addAnnotators(for: items)
        sceneController.highlightAnnotators(for: items, scrollTo: false)
    }
    
    func contentActionSelected(_ items: [ContentItem], by controller: ContentController) {
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        if let item = items.first {
            contentItemChanged(item, by: controller)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionConfirmed(_ items: [ContentItem], by controller: ContentController) {
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // scroll
        if let item = items.first {
            contentItemChanged(item, by: controller)
            sidebarController.updateItemInspector(for: item, submit: true)
        }
    }
    
    func contentActionDeleted(_ items: [ContentItem], by controller: ContentController) {
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

