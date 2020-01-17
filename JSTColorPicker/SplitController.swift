//
//  SplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ToolbarResponder {
    func useCursorAction(sender: NSToolbarItem)
    func useMagnifyToolAction(sender: NSToolbarItem)
    func useMinifyToolAction(sender: NSToolbarItem)
}

class SplitController: NSSplitViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    weak var windowController: WindowController?
    fileprivate var image: PixelImage?
    
    func openDocumentIfNeeded() {
        if image == nil {
            if let fileURL = windowController?.document?.fileURL as? URL {
                openItem(url: fileURL)
            }
        }
    }
    
    func openItem(url: URL) {
        debugPrint(url)
        do {
            let image = try PixelImage.init(contentsOf: url)
            self.image = image
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
    
    var acceptedFileExtensions: [String] {
        return ["png"]
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if let sceneController = sceneController {
            sceneController.trackingDelegate = self
        }
    }
    
    func dropView(_: DropSplitView?, didDropFileWith fileURL: NSURL) {
        openItem(url: fileURL as URL)
    }
    
}

extension SplitController: SceneTracking {
    
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool {
        guard let image = image else {
            return false
        }
        if let sidebarController = sidebarController {
            sidebarController.updateInspector(point: point, color: image.pixelImageRep.getJSTColor(of: point))
        }
        return true
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        if let title = image?.imageURL.lastPathComponent {
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

