//
//  ColorUndoManager.swift
//  JSTColorPanel
//
//  Created by Viktor Hundahl Strate on 25/06/2018.
//  Copyright © 2018 Viktor Hundahl Strate. All rights reserved.
//

import Cocoa

class ColorUndoManager  {
    fileprivate var history: [HSV] = []
    fileprivate var current: Int = 0
    
    var lastItem: Int {
        get {
            return history.count - 1
        }
    }
    
    var colorPanel: JSTColorPanel
    
    var canUndo: Bool {
        get {
            return current != 0
        }
    }
    
    var canRedo: Bool {
        get {
            return current != lastItem
        }
    }
    
    init(colorPanel: JSTColorPanel, initialColor color: HSV) {
        self.colorPanel = colorPanel
        self.history.append(color)
    }
    
    public func add(color: HSV) {
        Logger.debug(message: "Add new color to undo stack: \(color)")
        
        if self.lastItem != current {
            Logger.debug(message: "Removing undo tail")
            
            // if new color is added, and newer colors than the current exists, remove the newer colors
            history.removeLast(self.lastItem - current)
        }
        
        history.append(color)
        current = self.lastItem
    }
    
    public func undo() -> HSV {
        Logger.debug(message: "Undo color")
        
        if current > 0 {
            current -= 1
        }
        
        return history[current]
    }
    
    public func redo() -> HSV {
        if current < lastItem {
            Logger.debug(message: "Redo color")
            current += 1
        } else {
            Logger.debug(message: "Nothing to redo")
        }
        
        return history[current]
    }
}
