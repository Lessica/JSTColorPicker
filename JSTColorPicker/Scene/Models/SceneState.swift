//
//  SceneState.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


protocol SceneStateSource: AnyObject {
    var sceneState: SceneState { get }
    func beginEditing() -> EditableOverlay?
}

final class SceneState {
    
    enum ManipulatingSide {
        case none
        case left
        case right
        case other(buttonNumber: Int)
    }
    
    enum ManipulatingType {
        case none
        case leftGeneric
        case rightGeneric
        case otherGeneric(buttonNumber: Int)
        case areaDragging
        case sceneDragging
        case annotatorDragging
        case forbidden
        
        var level: Int {
            switch self {
            case .none:
                return 0
            case .leftGeneric, .rightGeneric, .otherGeneric:
                return 1
            case .areaDragging:
                return 2
            case .annotatorDragging:
                return 3
            case .sceneDragging:
                return 4
            case .forbidden:
                return Int.max
            }
        }
        
        static func draggingType(at side: ManipulatingSide, for tool: SceneTool) -> ManipulatingType {
            if case .left = side {
                switch tool {
                case .magicCursor, .magnifyingGlass:
                    return .areaDragging
                case .movingHand:
                    return .sceneDragging
                case .selectionArrow:
                    return .annotatorDragging
                default:
                    break
                }
            } else if case .right = side {
                switch tool {
                default:
                    return .sceneDragging
                }
            }
            return .forbidden
        }
        
        var isManipulating: Bool {
            switch self {
            case .none:
                return false
            default:
                return true
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .areaDragging, .sceneDragging, .annotatorDragging:
                return true
            default:
                return false
            }
        }
    }
    
    struct ManipulatingOptions: OptionSet {
        let rawValue: Int
        
        static let proportionalScaling  /* Shift Pressed  */ = ManipulatingOptions(rawValue: 1 << 0)
        static let centeredScaling      /* Option Pressed */ = ManipulatingOptions(rawValue: 1 << 1)

        var shouldClip: Bool { self.isEmpty }
    }
    
    var manipulatingSide                          = ManipulatingSide.none
    var manipulatingType                          = ManipulatingType.none
    var manipulatingOptions                       : ManipulatingOptions = []
    
    private var internalStage                     : Int = 0
    private var internalBeginLocation             : CGPoint = .null
    private weak var internalManipulatingOverlay  : EditableOverlay?
    
    var stage: Int
    {
        get {
            if case .none = manipulatingType {
                return 0
            }
            return internalStage
        }
        set { internalStage = newValue }
    }
    
    var beginLocation: CGPoint
    {
        get {
            if case .none = manipulatingType {
                return .null
            }
            return internalBeginLocation
        }
        set { internalBeginLocation = newValue }
    }
    
    var manipulatingOverlay: EditableOverlay?
    {
        get {
            if case .none = manipulatingType {
                return nil
            }
            return internalManipulatingOverlay
        }
        set { internalManipulatingOverlay = newValue }
    }
    
    var isManipulating         : Bool { manipulatingType.isManipulating }
    var isDragging             : Bool { manipulatingType.isDragging     }
    var isProportionalScaling  : Bool { manipulatingOptions.contains(.proportionalScaling) }
    var isCenteredScaling      : Bool { manipulatingOptions.contains(.centeredScaling)     }
    
    func reset() {
        manipulatingSide = .none
        manipulatingType = .none
        manipulatingOptions = []
        internalStage = 0
        internalBeginLocation = .null
        internalManipulatingOverlay = nil
    }
    
}

