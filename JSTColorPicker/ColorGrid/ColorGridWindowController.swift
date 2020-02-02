//
//  ColorGridWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/19/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorGridWindowController: NSWindowController {

    static func newGrid() -> ColorGridWindowController {
        let windowStoryboard = NSStoryboard(name: "ColorGrid", bundle: nil)
        let gridWindowController = windowStoryboard.instantiateInitialController() as! ColorGridWindowController
        gridWindowController.window?.level = .floating
        return gridWindowController
    }
    
    var activeWindowController: WindowController? {
        didSet {
            guard let windowController = activeWindowController else { return }
            guard let gridView = gridView else { return }
            gridView.dataSource = windowController
        }
    }
    
    fileprivate var gridView: ColorGridView? {
        guard let viewController = window?.contentViewController as? ColorGridViewController else { return nil }
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

extension ColorGridWindowController: SceneTracking {
    
    func mousePositionChanged(_ sender: Any, to coordinate: PixelCoordinate) {
        guard let shouldTrack = window?.isVisible else { return }
        if shouldTrack {
            gridView?.centerCoordinate = coordinate
        }
    }
    
}

extension ColorGridWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        gridView?.animating = false
    }
    
}
