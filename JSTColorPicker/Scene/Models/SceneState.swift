//
//  SceneState.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


protocol SceneStateSource: class {
    var sceneState: SceneState { get }
    func beginEditing() -> EditableOverlay?
}

class SceneState {
    
    enum ManipulatingType {
        case none
        case leftGeneric
        case rightGeneric
        case areaDragging
        case sceneDragging
        case annotatorDragging
        case forbidden
        
        var level: Int {
            switch self {
            case .none:
                return 0
            case .leftGeneric, .rightGeneric:
                return 1
            case .areaDragging, .sceneDragging:
                return 2
            case .annotatorDragging:
                return 3
            case .forbidden:
                return Int.max
            }
        }
        
        static func leftDraggingType(for tool: SceneTool) -> ManipulatingType {
            switch tool {
            case .magicCursor, .magnifyingGlass:
                return .areaDragging
            case .movingHand:
                return .sceneDragging
            case .selectionArrow:
                return .annotatorDragging
            default:
                return .forbidden
            }
        }
        
        static func rightDraggingType(for tool: SceneTool) -> ManipulatingType {
            return .forbidden
        }
        
        var isManipulating: Bool { self != .none }
        
        var isDragging: Bool {
            if self == .sceneDragging || self == .areaDragging || self == .annotatorDragging {
                return true
            }
            return false
        }
    }
    
    struct ManipulatingOptions: OptionSet {
        let rawValue: Int
        
        static let proportionalScaling  /* Shift Pressed  */ = ManipulatingOptions(rawValue: 1 << 0)
        static let centeredScaling      /* Option Pressed */ = ManipulatingOptions(rawValue: 1 << 1)

        var shouldClip: Bool { self.isEmpty }
    }
    
    var manipulatingType                          = ManipulatingType.none
    var manipulatingOptions                       : ManipulatingOptions = []
    
    private var internalStage                     : Int = 0
    private var internalBeginLocation             : CGPoint = .null
    private weak var internalManipulatingOverlay  : EditableOverlay?
    
    var stage: Int
    {
        get { manipulatingType != .none ? internalStage : 0 }
        set { internalStage = newValue                      }
    }
    
    var beginLocation: CGPoint
    {
        get { manipulatingType != .none ? internalBeginLocation : .null }
        set { internalBeginLocation = newValue                          }
    }
    
    var manipulatingOverlay: EditableOverlay?
    {
        get { manipulatingType != .none ? internalManipulatingOverlay : nil }
        set { internalManipulatingOverlay = newValue                        }
    }
    
    var isManipulating  : Bool { manipulatingType.isManipulating }
    var isDragging      : Bool { manipulatingType.isDragging     }
    
    func reset() {
        manipulatingType = .none
        manipulatingOptions = []
        internalStage = 0
        internalBeginLocation = .null
        internalManipulatingOverlay = nil
    }
    
}

