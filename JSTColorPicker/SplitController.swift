//
//  SplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

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

    var image: PixelImage?
    
}

extension SplitController: DropViewDelegate {
    
    var acceptedFileExtensions: [String] {
        return ["png"]
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if let sceneController = children.first as? SceneController {
            sceneController.trackingDelegate = self
        }
    }
    
    func dropView(_: DropSplitView?, didDropFileWith fileURL: NSURL) {
        debugPrint(fileURL)
        do {
            let image = try PixelImage.init(contentsOf: fileURL as URL)
            if let title = fileURL.lastPathComponent {
                view.window?.title = title
            }
            if let sceneController = children.first as? SceneController {
                sceneController.resetController()
                sceneController.renderImage(image)
            }
            if let sidebarController = children.last as? SidebarController {
                sidebarController.resetController()
                try sidebarController.renderImageSource(image.imageSourceRep, itemURL: fileURL as URL)
            }
            self.image = image
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
}

extension SplitController: SceneTracking {
    func mousePositionChanged(_ wrapper: SceneImageWrapper, toPoint point: CGPoint) {
        guard let image = image else {
            return
        }
        if let sidebarController = children.last as? SidebarController {
            sidebarController.updateInspector(point: point, color: image.pixelImageRep.getJSTColor(of: point))
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

extension SplitController {
    
    func loadImageAction(sender: NSToolbarItem) {
        if let url = NSOpenPanel().selectUrl {
            debugPrint("selected: ", url.path)
            dropView(nil, didDropFileWith: url as NSURL)
        } else {
            debugPrint("selection was canceled")
        }
    }
    
    func useCursorAction(sender: NSToolbarItem) {
        
    }
    
    func useMagnifyToolAction(sender: NSToolbarItem) {
        
    }
    
    func useMinifyToolAction(sender: NSToolbarItem) {
        
    }
    
}

