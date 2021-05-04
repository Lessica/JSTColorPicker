//
//  SceneEvent.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class SceneEventObserver: NSResponder {

    struct EventOrder: OptionSet {
        let rawValue: Int
        
        static let before         = EventOrder(rawValue: 1 << 0)
        static let after          = EventOrder(rawValue: 1 << 1)
        
        static let all: EventOrder = [.before, .after]
    }
    
    var types = [NSEvent.EventType]()
    var order = EventOrder()
    weak var target: NSResponder?
    
    init(_ target: NSResponder, types: [NSEvent.EventType], order: EventOrder) {
        self.target = target
        self.types = types
        self.order = order
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

