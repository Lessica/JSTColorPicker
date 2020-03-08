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
    
    static let mouseDown         = SceneEventType(rawValue: 1 << 0)
    static let rightMouseDown    = SceneEventType(rawValue: 1 << 1)
    static let mouseUp           = SceneEventType(rawValue: 1 << 2)
    static let rightMouseUp      = SceneEventType(rawValue: 1 << 3)
    static let mouseDragged      = SceneEventType(rawValue: 1 << 4)
    static let rightMouseDragged = SceneEventType(rawValue: 1 << 5)
    static let scrollWheel       = SceneEventType(rawValue: 1 << 6)
    static let magnify           = SceneEventType(rawValue: 1 << 7)
    static let smartMagnify      = SceneEventType(rawValue: 1 << 8)
    
    static let all: SceneEventType = [
        .mouseDown, .rightMouseDown, .mouseUp, .rightMouseUp,
        .mouseDragged, .rightMouseDragged, .scrollWheel, .magnify,
        .smartMagnify
    ]
}

struct SceneEventOrder: OptionSet {
    let rawValue: Int
    
    static let before         = SceneEventOrder(rawValue: 1 << 0)
    static let after          = SceneEventOrder(rawValue: 1 << 1)
    
    static let all: SceneEventOrder = [.before, .after]
}

class SceneEventObserver: NSResponder {
    public var types = SceneEventType()
    public var order = SceneEventOrder()
    public weak var target: NSResponder?
    
    init(_ target: NSResponder, types: SceneEventType, order: SceneEventOrder) {
        self.target = target
        self.types = types
        self.order = order
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
