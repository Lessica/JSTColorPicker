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
    var sceneToolEnabled: Bool { get }
    func resetSceneTool()
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
    
    private static var resizeNorthWestSouthEast: NSCursor = {
        return NSCursor.init(image: NSImage(named: "resizenorthwestsoutheast")!, hotSpot: NSPoint(x: 17, y: 17))
    }()
    
    private static var resizeNorthSouth: NSCursor = {
        return NSCursor.init(image: NSImage(named: "resizenorthsouth")!, hotSpot: NSPoint(x: 17, y: 17))
    }()
    
    private static var resizeNorthEastSouthWest: NSCursor = {
        return NSCursor.init(image: NSImage(named: "resizenortheastsouthwest")!, hotSpot: NSPoint(x: 17, y: 17))
    }()
    
    private static var resizeEastWest: NSCursor = {
        return NSCursor.init(image: NSImage(named: "resizeeastwest")!, hotSpot: NSPoint(x: 17, y: 17))
    }()
    
    public var normalCursor: NSCursor {
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
    
    public var disabledCursor: NSCursor {
        switch self {
        case .magnifyingGlass:
            return SceneTool.noZoomingCursor
        case .minifyingGlass:
            return SceneTool.noZoomingCursor
        default:
            return NSCursor.operationNotAllowed
        }
    }
    
    public var manipulatingCursor: NSCursor {
        switch self {
        case .movingHand:
            return NSCursor.closedHand
        default:
            return NSCursor.current
        }
    }
    
    public func focusingCursorForEditableDirection(_ direction: EditableDirection) -> NSCursor {
        switch self {
        case .selectionArrow:
            switch direction {
            case .northWestSouthEast:
                return SceneTool.resizeNorthWestSouthEast
            case .northSouth:
                return SceneTool.resizeNorthSouth
            case .northEastSouthWest:
                return SceneTool.resizeNorthEastSouthWest
            case .eastWest:
                return SceneTool.resizeEastWest
            case .none:
                return NSCursor.pointingHand
            }
        default:
            return NSCursor.current
        }
    }
    
}
