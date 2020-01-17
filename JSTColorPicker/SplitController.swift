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
    
    internal var acceptedFileExtensions: [String] {
        return ["png"]
    }
    
    func dropView(_: DropSplitView?, didDropFileWith fileURL: NSURL) {
        // not implemented
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
        return true
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        if let title = document?.image?.imageURL.lastPathComponent {
            windowTitle = "\(title) @ \(Int((magnification * 100.0).rounded(.toNearestOrEven)))%"
        }
    }
    
}

extension SplitController: ToolbarResponder {
    
    func useCursorAction(sender: NSToolbarItem) {
        sceneController?.useCursorAction(sender: sender)
    }
    
    func useMagnifyToolAction(sender: NSToolbarItem) {
        sceneController?.useMagnifyToolAction(sender: sender)
    }
    
    func useMinifyToolAction(sender: NSToolbarItem) {
        sceneController?.useMinifyToolAction(sender: sender)
    }
    
}

