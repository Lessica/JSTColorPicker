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
    
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool {
        guard let image = screenshot?.image else { return false }
        sidebarController.updateInspector(point: point, color: image.pixelImageRep.getJSTColor(of: point), submit: false)
        _ = trackingObject?.mousePositionChanged(sender, toPoint: point)
        return true
    }
    
    func mouseClicked(_ sender: Any, atPoint point: CGPoint) {
        guard let image = screenshot?.image else { return }
        let color = image.pixelImageRep.getJSTColor(of: point)
        sidebarController.updateInspector(point: point, color: color, submit: true)
        do {
            _ = try contentController.submitContent(point: point, color: color)
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
        // TODO: implement Content protocol
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        if let title = screenshot?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        _ = trackingObject?.sceneMagnificationChanged(sender, toMagnification: magnification)
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
    
    func fitWindowAction(_ sender: Any?) {
        sceneController.fitWindowAction(sender)
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
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
}

extension SplitController: ContentActionDelegate {
    
    func contentActionAdded(_ item: PixelColor, by controller: ContentController) {
        sceneController.addAnnotator(for: item)
    }
    
    func contentActionSelected(_ items: [PixelColor], by controller: ContentController) {
        if let item = items.first {
            let point = item.coordinate.toCGPoint()
            _ = trackingObject?.mousePositionChanged(controller, toPoint: point)
            sidebarController.updateInspector(point: point, color: item.pixelColorRep, submit: true)
        }
        sceneController.highlightAnnotators(for: items, scrollTo: false)
    }
    
    func contentActionConfirmed(_ items: [PixelColor], by controller: ContentController) {
        if let item = items.first {
            let point = item.coordinate.toCGPoint()
            _ = trackingObject?.mousePositionChanged(controller, toPoint: point)
            sidebarController.updateInspector(point: point, color: item.pixelColorRep, submit: true)
        }
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // scroll
    }
    
    func contentActionDeleted(_ items: [PixelColor], by controller: ContentController) {
        sceneController.removeAnnotators(for: items)
    }
    
}

