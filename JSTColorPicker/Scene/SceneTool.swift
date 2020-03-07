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
    func sceneToolEnabled(_ sender: Any) -> Bool
}

enum SceneTool: String {
    
    case arrow = ""
    case magicCursor = "AnnotateItem"
    case magnifyingGlass = "MagnifyItem"
    case minifyingGlass = "MinifyItem"
    case selectionArrow = "SelectItem"
    case movingHand = "MoveItem"
    
    static var arrowCursor: NSCursor = {
        return NSCursor.arrow
    }()
    
    static var magnifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMagnifyMIN")!, hotSpot: NSPoint(x: 15, y: 15))
    }()
    
    static var minifyCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTMinifyMIN")!, hotSpot: NSPoint(x: 15, y: 15))
    }()
    
    static var noZoomingCursor: NSCursor = {
        return NSCursor.init(image: NSImage(named: "JSTNoZoomingMIN")!, hotSpot: NSPoint(x: 15, y: 15))
    }()
    
    var normalCursor: NSCursor {
        switch self {
        case .magicCursor:
            return NSCursor.crosshair
        case .magnifyingGlass:
            return SceneTool.magnifyCursor
        case .minifyingGlass:
            return SceneTool.minifyCursor
        case .selectionArrow:
            return NSCursor.arrow
        case .movingHand:
            return NSCursor.openHand
        default:
            return NSCursor.current
        }
    }
    
    var disabledCursor: NSCursor {
        switch self {
        case .magnifyingGlass:
            return SceneTool.noZoomingCursor
        case .minifyingGlass:
            return SceneTool.noZoomingCursor
        default:
            return NSCursor.operationNotAllowed
        }
    }
    
    var manipulatingCursor: NSCursor {
        switch self {
        case .movingHand:
            return NSCursor.closedHand
        default:
            return NSCursor.current
        }
    }
    
    var focusingCursor: NSCursor {
        switch self {
        case .selectionArrow:
            return NSCursor.pointingHand
        default:
            return NSCursor.current
        }
    }
    
}
