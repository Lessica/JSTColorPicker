//
//  GridWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class GridWindowController: NSWindowController {
    
    static let shared = newController()

    private static func newController() -> GridWindowController {
        let windowStoryboard = NSStoryboard(name: "Grid", bundle: nil)
        let windowController = windowStoryboard.instantiateInitialController() as! GridWindowController
        return windowController
    }
    
    var activeWindowController: WindowController? {
        didSet {
            guard let windowController = activeWindowController else { return }
            guard let gridView = gridView else { return }
            gridView.dataSource = windowController
        }
    }
    
    var isVisible: Bool { window?.isVisible ?? false }
    
    private var gridView: GridView? {
        guard let viewController = window?.contentViewController as? GridViewController else { return nil }
        return viewController.gridView
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isEnabled = false
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        gridView?.animating = true
    }

}

extension GridWindowController: SceneTracking {
    
    func sceneRawColorDidChange(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) {
        gridView?.centerCoordinate = coordinate
    }
    
}

extension GridWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        gridView?.animating = false
    }
    
}
