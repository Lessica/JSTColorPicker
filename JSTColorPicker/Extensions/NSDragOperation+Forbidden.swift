//
//  NSDragOperation+Forbidden.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/4/29.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

extension NSDragOperation {
    
    static let forbidden = NSDragOperation(rawValue: UInt.max)
}
