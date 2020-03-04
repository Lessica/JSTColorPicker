//
//  TrackingTool.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TrackingToolDataSource: class {
    var trackingTool: TrackingTool { get }
    func trackingToolEnabled(_ sender: Any, tool: TrackingTool) -> Bool
}

enum TrackingTool: String {
    
    case arrow = ""
    case magicCursor = "CursorItem"
    case magnifyingGlass = "MagnifyItem"
    case minifyingGlass = "MinifyItem"
    case movingHand = "MoveItem"
    
    static var arrowCursor: NSCursor = {
        return NSCursor.arrow
    }()
    
    static var magnifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMagnifyMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    static var minifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMinifyMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    static var noZoomingCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTNoZoomingMIN")!, hotSpot: NSPoint(x: 8, y: 8))
    }()
    
    var currentCursor: NSCursor {
        get {
            if self == .magicCursor {
                return NSCursor.crosshair
            } else if self == .magnifyingGlass {
                return TrackingTool.magnifyCursor
            } else if self == .minifyingGlass {
                return TrackingTool.minifyCursor
            } else if self == .movingHand {
                return NSCursor.openHand
            }
            return NSCursor.current
        }
    }
    
    var highlightCursor: NSCursor {
        get {
            if self == .magicCursor {
                return NSCursor.crosshair
            } else if self == .magnifyingGlass {
                return TrackingTool.magnifyCursor
            } else if self == .minifyingGlass {
                return TrackingTool.minifyCursor
            } else if self == .movingHand {
                return NSCursor.closedHand
            }
            return NSCursor.current
        }
    }
    
    var disabledCursor: NSCursor {
        get {
            if self == .magicCursor {
                return NSCursor.operationNotAllowed
            } else if self == .magnifyingGlass {
                return TrackingTool.noZoomingCursor
            } else if self == .minifyingGlass {
                return TrackingTool.noZoomingCursor
            } else if self == .movingHand {
                return NSCursor.operationNotAllowed
            }
            return NSCursor.current
        }
    }
    
}
