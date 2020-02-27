//
//  SceneOverlayView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

// TODO: Find a better way to draw annotators in a more efficient way
class SceneOverlayView: NSView {
    
//    fileprivate var trackingArea: NSTrackingArea?
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
//    fileprivate func createTrackingArea() {
//        let trackingArea = NSTrackingArea.init(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
//        addTrackingArea(trackingArea)
//        self.trackingArea = trackingArea
//    }
//    
//    override func updateTrackingAreas() {
//        if let trackingArea = trackingArea {
//            removeTrackingArea(trackingArea)
//        }
//        createTrackingArea()
//        super.updateTrackingAreas()
//    }
    
}
