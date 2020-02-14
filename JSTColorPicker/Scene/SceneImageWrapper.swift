//
//  SceneImageWrapper.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol RulerViewClient: class {
    func rulerView(_ ruler: RulerView?, shouldAdd marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, shouldMove marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, shouldRemove marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, didAdd marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, didMove marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, didRemove marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, willMove marker: RulerMarker, toLocation location: Int) -> Int
}

class SceneImageWrapper: NSView {
    
    weak var rulerViewClient: RulerViewClient?
    
    override var isFlipped: Bool {
        return true
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }  // disable user interactions
    
    override func cursorUpdate(with event: NSEvent) {
        // do not perform default behavior
    }
    
    override func rulerView(_ ruler: NSRulerView, shouldAdd marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldAdd: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, shouldMove marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldMove: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, shouldRemove marker: NSRulerMarker) -> Bool {
        return rulerViewClient?.rulerView(ruler as? RulerView, shouldRemove: marker as! RulerMarker) ?? false
    }
    
    override func rulerView(_ ruler: NSRulerView, willMove marker: NSRulerMarker, toLocation location: CGFloat) -> CGFloat {
        return CGFloat(rulerViewClient?.rulerView(ruler as? RulerView, willMove: marker as! RulerMarker, toLocation: Int(round(location))) ?? Int(round(location)))
    }
    
    override func rulerView(_ ruler: NSRulerView, didAdd marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didAdd: marker as! RulerMarker)
    }
    
    override func rulerView(_ ruler: NSRulerView, didMove marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didMove: marker as! RulerMarker)
    }
    
    override func rulerView(_ ruler: NSRulerView, didRemove marker: NSRulerMarker) {
        rulerViewClient?.rulerView(ruler as? RulerView, didRemove: marker as! RulerMarker)
    }
    
}
