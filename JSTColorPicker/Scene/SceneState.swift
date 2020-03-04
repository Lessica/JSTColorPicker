//
//  SceneState.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol SceneStateDataSource: class {
    var sceneState: SceneState { get }
}

enum SceneManipulatingType {
    case none
    case forbidden
    case leftGeneric
    case rightGeneric
    case basicDragging
    case areaDragging
    
    public static func leftDraggingType(for tool: TrackingTool) -> SceneManipulatingType {
        switch tool {
        case .magicCursor, .magnifyingGlass:
            return .areaDragging
        case .movingHand:
            return .basicDragging
        default:
            return .forbidden
        }
    }
    public static func rightDraggingType(for tool: TrackingTool) -> SceneManipulatingType {
        return .forbidden
    }
    public var isManipulating: Bool {
        return self != .none
    }
    public var isDragging: Bool {
        if self == .basicDragging || self == .areaDragging {
            return true
        }
        return false
    }
}

class SceneState {
    public var type: SceneManipulatingType = .none
    private var internalStage: Int = 0
    private var internalBeginLocation: CGPoint = .null
    
    public var stage: Int {
        get {
            return type != .none ? internalStage : 0
        }
        set {
            internalStage = newValue
        }
    }
    public var beginLocation: CGPoint {
        get {
            return type != .none ? internalBeginLocation : .null
        }
        set {
            internalBeginLocation = newValue
        }
    }
    public var isManipulating: Bool {
        return type.isManipulating
    }
    public var isDragging: Bool {
        return type.isDragging
    }
}
