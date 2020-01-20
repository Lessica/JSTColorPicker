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
        return windowStoryboard.instantiateInitialController() as! ColorGridWindowController
    }
    
    var gridView: ColorGridView? {
        guard let viewController = window?.contentViewController as? ColorGridViewController else { return nil }
        return viewController.gridView
    }
    var activeWindowController: WindowController? {
        didSet {
            guard let gridView = gridView else { return }
            guard let screenshot = activeWindowController?.document as? Screenshot else { return }
            gridView.image = screenshot.image
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        gridView?.animating = true
    }

}

extension ColorGridWindowController: SceneTracking {
    
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool {
        guard let shouldTrack = window?.isVisible else { return false }
        if shouldTrack {
            gridView?.centerPoint = point
        }
        return shouldTrack
    }
    
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) {
        // not implemented
    }
    
}

extension ColorGridWindowController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        gridView?.animating = false
    }
    
}
