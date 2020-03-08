//
//  SceneState.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneStateDataSource: class {
    var sceneState: SceneState { get }
    var overlayAtBeginLocation: Overlay? { get }
}

enum SceneManipulatingType {
    
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
    public static func leftDraggingType(for tool: SceneTool) -> SceneManipulatingType {
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
    public static func rightDraggingType(for tool: SceneTool) -> SceneManipulatingType {
        return .forbidden
    }
    public var isManipulating: Bool {
        return self != .none
    }
    public var isDragging: Bool {
        if self == .sceneDragging || self == .areaDragging || self == .annotatorDragging {
            return true
        }
        return false
    }
}

class SceneState {
    public var type: SceneManipulatingType = .none
    private var internalStage: Int = 0
    private var internalBeginLocation: CGPoint = .null
    private weak var internalManipulatingOverlay: Overlay?
    
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
    public var manipulatingOverlay: Overlay? {
        get {
            return type != .none ? internalManipulatingOverlay : nil
        }
        set {
            internalManipulatingOverlay = newValue
        }
    }
    public var isManipulating: Bool {
        return type.isManipulating
    }
    public var isDragging: Bool {
        return type.isDragging
    }
    public func reset() {
        type = .none
        internalStage = 0
        internalBeginLocation = .null
        internalManipulatingOverlay = nil
    }
}
