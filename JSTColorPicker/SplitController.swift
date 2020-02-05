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
    
    func trackCursorPositionChanged(_ sender: Any, to coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        sidebarController.updateInspector(coordinate: coordinate, color: image.pixelImageRep.getJSTColor(of: coordinate.toCGPoint()), submit: false)
        trackingObject?.trackCursorPositionChanged(sender, to: coordinate)
    }
    
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) {
        guard let image = screenshot?.image else { return }
        let color = image.pixelImageRep.getJSTColor(of: coordinate.toCGPoint())
        sidebarController.updateInspector(coordinate: coordinate, color: color, submit: true)
        do {
            _ = try contentController.submitItem(at: coordinate, color: color)
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
    
    func trackSceneMagnificationChanged(_ sender: Any, to magnification: CGFloat) {
        if let title = screenshot?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        trackingObject?.trackSceneMagnificationChanged(sender, to: magnification)
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
    
    func contentActionAdded(_ items: [ContentItem], by controller: ContentController) {
        sceneController.addAnnotators(for: items)
        sceneController.highlightAnnotators(for: items, scrollTo: false)
    }
    
    func contentActionSelected(_ items: [ContentItem], by controller: ContentController) {
        sceneController.highlightAnnotators(for: items, scrollTo: false)
        if let item = items.first as? PixelColor {
            trackingObject?.trackCursorPositionChanged(controller, to: item.coordinate)
            sidebarController.updateInspector(coordinate: item.coordinate, color: item.pixelColorRep, submit: true)
        }
    }
    
    func contentActionConfirmed(_ items: [ContentItem], by controller: ContentController) {
        sceneController.highlightAnnotators(for: items, scrollTo: true)  // scroll
        if let item = items.first as? PixelColor {
            trackingObject?.trackCursorPositionChanged(controller, to: item.coordinate)
            sidebarController.updateInspector(coordinate: item.coordinate, color: item.pixelColorRep, submit: true)
        }
    }
    
    func contentActionDeleted(_ items: [ContentItem], by controller: ContentController) {
        sceneController.removeAnnotators(for: items)
        if let item = items.first as? PixelColor {
            trackingObject?.trackCursorPositionChanged(controller, to: item.coordinate)
        }
    }
    
}

