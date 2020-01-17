//
//  TrackingTool.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TrackingToolDelegate: class {
    func trackingToolEnabled(_ sender: Any, tool: TrackingTool) -> Bool
}

enum TrackingTool: String {
    
    case arrow = ""
    case cursor = "CursorItem"
    case magnify = "MagnifyItem"
    case minify = "MinifyItem"
    
    static var magnifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMagnifyMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    static var minifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMinifyMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    static var noZoomingCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTNoZoomingMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    var cursor: NSCursor {
        get {
            if self == .cursor {
                return NSCursor.crosshair
            } else if self == .magnify {
                return TrackingTool.magnifyCursor
            } else if self == .minify {
                return TrackingTool.minifyCursor
            }
            return NSCursor.current
        }
    }
    
    var disabledCursor: NSCursor {
        get {
            if self == .cursor {
                return NSCursor.crosshair
            } else if self == .magnify {
                return TrackingTool.noZoomingCursor
            } else if self == .minify {
                return TrackingTool.noZoomingCursor
            }
            return NSCursor.current
        }
    }
    
}
