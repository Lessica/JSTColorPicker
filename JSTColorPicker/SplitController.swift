//
//  SplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ToolbarResponder {
    func loadImageAction(sender: NSToolbarItem)
    func useCursorAction(sender: NSToolbarItem)
    func useMagnifyToolAction(sender: NSToolbarItem)
    func useMinifyToolAction(sender: NSToolbarItem)
}

extension ToolbarResponder {
    func loadImageAction(sender: NSToolbarItem) {
        // default implementation to make it optional
    }
}

class SplitController: NSSplitViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    fileprivate var image: PixelImage?
    
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
        debugPrint(fileURL)
        do {
            let image = try PixelImage.init(contentsOf: fileURL as URL)
            self.image = image
            if let sceneController = sceneController {
                sceneController.resetController()
                sceneController.renderImage(image)
            }
            if let sidebarController = sidebarController {
                sidebarController.resetController()
                try sidebarController.renderImageSource(image.imageSourceRep, itemURL: fileURL as URL)
            }
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
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

extension NSOpenPanel {
    
    var selectUrl: URL? {
        title = "Select Screenshot"
        allowsMultipleSelection = false
        canChooseDirectories = false
        canChooseFiles = true
        canCreateDirectories = false
        allowedFileTypes = ["png"]
        return runModal() == .OK ? urls.first : nil
    }
    
    var selectUrls: [URL]? {
        title = "Select Screenshots"
        allowsMultipleSelection = true
        canChooseDirectories = false
        canChooseFiles = true
        canCreateDirectories = false
        allowedFileTypes = ["png"]
        return runModal() == .OK ? urls : nil
    }
    
}

extension SplitController: ToolbarResponder {
    
    func loadImageAction(sender: NSToolbarItem) {
        if let url = NSOpenPanel().selectUrl {
            debugPrint("selected: ", url.path)
            dropView(nil, didDropFileWith: url as NSURL)
        } else {
            debugPrint("selection was canceled")
        }
    }
    
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

