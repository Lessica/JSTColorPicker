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
        if let sceneController = sceneController {
            sceneController.trackingDelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadDocument()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    weak var windowController: WindowController?
    fileprivate var document: Screenshot? {
        get {
            return windowController?.document as? Screenshot
        }
    }
    fileprivate var documentObservation: NSKeyValueObservation?
    
    func loadDocument() {
        guard let image = document?.image else { return }
        guard let url = document?.fileURL else { return }
        do {
            if let sceneController = sceneController {
                sceneController.resetController()
                sceneController.renderImage(image)
            }
            if let sidebarController = sidebarController {
                sidebarController.resetController()
                try sidebarController.renderImageSource(image.imageSourceRep, itemURL: url)
            }
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
    deinit {
        debugPrint("- [SplitController deinit]")
    }
    
}

extension SplitController: DropViewDelegate {
    
    fileprivate var sceneController: SceneController? {
        get {
            if let sceneController = children.first as? SceneController {
                return sceneController
            }
            return nil
        }
    }
    
    fileprivate var sidebarController: SidebarController? {
        get {
            if let sidebarController = children.last as? SidebarController {
                return sidebarController
            }
            return nil
        }
    }
    
    fileprivate var windowTitle: String {
        get {
            if let title = view.window?.title {
                return title
            }
            return ""
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
        guard let image = document?.image else {
            return false
        }
        if let sidebarController = sidebarController {
            sidebarController.updateInspector(point: point, color: image.pixelImageRep.getJSTColor(of: point))
        }
        _ = windowController?.mousePositionChanged(sender, toPoint: point)
        return true
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        if let title = document?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
        windowController?.sceneMagnificationChanged(sender, toMagnification: magnification)
    }
    
}

extension SplitController: ToolbarResponder {
    
    func useCursorAction(_ sender: Any?) {
        sceneController?.useCursorAction(sender)
    }
    
    func useMagnifyToolAction(_ sender: Any?) {
        sceneController?.useMagnifyToolAction(sender)
    }
    
    func useMinifyToolAction(_ sender: Any?) {
        sceneController?.useMinifyToolAction(sender)
    }
    
    func fitWindowAction(_ sender: Any?) {
        sceneController?.fitWindowAction(sender)
    }
    
}

