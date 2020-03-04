//
//  SceneTool.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneToolDataSource: class {
    var sceneTool: SceneTool { get }
    func sceneToolEnabled(_ sender: Any, tool: SceneTool) -> Bool
}

enum SceneTool: String {
    
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
                return SceneTool.magnifyCursor
            } else if self == .minifyingGlass {
                return SceneTool.minifyCursor
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
                return SceneTool.magnifyCursor
            } else if self == .minifyingGlass {
                return SceneTool.minifyCursor
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
                return SceneTool.noZoomingCursor
            } else if self == .minifyingGlass {
                return SceneTool.noZoomingCursor
            } else if self == .movingHand {
                return NSCursor.operationNotAllowed
            }
            return NSCursor.current
        }
    }
    
}
