//
//  SceneEvent.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

struct SceneEventType: OptionSet {
    let rawValue: Int
    
    static let leftMouseDown     = SceneEventType(rawValue: 1 << 0)
    static let rightMouseDown    = SceneEventType(rawValue: 1 << 1)
    static let leftMouseUp       = SceneEventType(rawValue: 1 << 2)
    static let rightMouseUp      = SceneEventType(rawValue: 1 << 3)
    static let leftMouseDragged  = SceneEventType(rawValue: 1 << 4)
    static let rightMouseDragged = SceneEventType(rawValue: 1 << 5)
}

class SceneEventObserver {
    public var types = SceneEventType()
    public weak var target: NSResponder?
}
