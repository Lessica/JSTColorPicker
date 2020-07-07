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
    var editingAnnotatorOverlayAtBeginLocation: EditableOverlay? { get }
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
        
        public var level: Int {
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
        
        public static func leftDraggingType(for tool: SceneTool) -> ManipulatingType {
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
        
        public static func rightDraggingType(for tool: SceneTool) -> ManipulatingType {
            return .forbidden
        }
        
        public var isManipulating: Bool { self != .none }
        
        public var isDragging: Bool {
            if self == .sceneDragging || self == .areaDragging || self == .annotatorDragging {
                return true
            }
            return false
        }
        
    }
    
    public var manipulatingType                   = ManipulatingType.none
    private var internalStage                     : Int = 0
    private var internalBeginLocation             : CGPoint = .null
    private weak var internalManipulatingOverlay  : EditableOverlay?
    
    public var stage: Int
    {
        get { manipulatingType != .none ? internalStage : 0 }
        set { internalStage = newValue                      }
    }
    
    public var beginLocation: CGPoint
    {
        get { manipulatingType != .none ? internalBeginLocation : .null }
        set { internalBeginLocation = newValue                          }
    }
    
    public var manipulatingOverlay: EditableOverlay?
    {
        get { manipulatingType != .none ? internalManipulatingOverlay : nil }
        set { internalManipulatingOverlay = newValue                        }
    }
    
    public var isManipulating  : Bool { manipulatingType.isManipulating }
    public var isDragging      : Bool { manipulatingType.isDragging     }
    
    public func reset() {
        manipulatingType = .none
        internalStage = 0
        internalBeginLocation = .null
        internalManipulatingOverlay = nil
    }
    
}

