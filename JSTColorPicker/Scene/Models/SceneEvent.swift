//
//  SceneEvent.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class SceneEventObserver: NSResponder {
    
    struct EventType: OptionSet {
        let rawValue: Int
        
        static let mouseDown         = EventType(rawValue: 1 << 0)
        static let rightMouseDown    = EventType(rawValue: 1 << 1)
        static let mouseUp           = EventType(rawValue: 1 << 2)
        static let rightMouseUp      = EventType(rawValue: 1 << 3)
        static let mouseDragged      = EventType(rawValue: 1 << 4)
        static let rightMouseDragged = EventType(rawValue: 1 << 5)
        static let scrollWheel       = EventType(rawValue: 1 << 6)
        static let magnify           = EventType(rawValue: 1 << 7)
        static let smartMagnify      = EventType(rawValue: 1 << 8)
        
        static let all: EventType = [
            .mouseDown, .rightMouseDown, .mouseUp, .rightMouseUp,
            .mouseDragged, .rightMouseDragged, .scrollWheel, .magnify,
            .smartMagnify
        ]
    }

    struct EventOrder: OptionSet {
        let rawValue: Int
        
        static let before         = EventOrder(rawValue: 1 << 0)
        static let after          = EventOrder(rawValue: 1 << 1)
        
        static let all: EventOrder = [.before, .after]
    }
    
    public var types = EventType()
    public var order = EventOrder()
    public weak var target: NSResponder?
    
    init(_ target: NSResponder, types: EventType, order: EventOrder) {
        self.target = target
        self.types = types
        self.order = order
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

