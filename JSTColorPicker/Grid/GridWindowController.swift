//
//  GridWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class GridWindowController: NSWindowController {

    static func newGrid() -> GridWindowController {
        let windowStoryboard = NSStoryboard(name: "Grid", bundle: nil)
        let gridWindowController = windowStoryboard.instantiateInitialController() as! GridWindowController
        return gridWindowController
    }
    
    var activeWindowController: WindowController? {
        didSet {
            guard let windowController = activeWindowController else { return }
            guard let gridView = gridView else { return }
            gridView.dataSource = windowController
        }
    }
    
    fileprivate var gridView: GridView? {
        guard let viewController = window?.contentViewController as? GridViewController else { return nil }
        return viewController.gridView
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        gridView?.animating = true
    }

}

extension GridWindowController: SceneTracking {
    
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) {
        gridView?.centerCoordinate = coordinate
    }
    
}

extension GridWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        gridView?.animating = false
    }
    
}