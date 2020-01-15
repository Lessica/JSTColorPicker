//
//  PickerSplitViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class PickerSplitController: NSSplitViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    var image: PickerImage?
    
}

extension PickerSplitController: DropViewDelegate {
    
    var acceptedFileExtensions: [String] {
        return ["png"]
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if let sceneController = children.first as? SceneController {
            sceneController.trackingDelegate = self
        }
    }
    
    func dropView(_: PickerDropSplitView, didDropFileWith fileURL: NSURL) {
        debugPrint(fileURL)
        do {
            let image = try PickerImage.init(contentsOf: fileURL as URL)
            if let title = fileURL.lastPathComponent {
                view.window?.title = title
            }
            if let sceneController = children.first as? SceneController {
                sceneController.renderImage(image)
            }
            if let sidebarController = children.last as? SidebarController {
                try sidebarController.renderImageSource(image.imageSourceRep, itemURL: fileURL as URL)
            }
            self.image = image
        } catch let error {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    
}

extension PickerSplitController: SceneTracking {
    func mousePositionChanged(_ wrapper: SceneImageWrapper, toPoint point: CGPoint) {
        guard let image = image else {
            return
        }
        if let sidebarController = children.last as? SidebarController {
            sidebarController.updateInspector(point: point, color: image.pixelImageRep.getJSTColor(of: point))
        }
    }
}

