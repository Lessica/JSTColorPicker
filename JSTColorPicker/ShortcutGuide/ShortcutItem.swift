//
//  ShortcutItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

public struct ShortcutItem {
    let name: String
    let keyString: String
    let toolTip: String
    let modifierFlags: NSEvent.ModifierFlags
}
