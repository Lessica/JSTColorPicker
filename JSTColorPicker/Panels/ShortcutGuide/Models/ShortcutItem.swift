//
//  ShortcutItem.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

public struct ShortcutItem {
    public init(name: String, toolTip: String, modifierFlags: NSEvent.ModifierFlags, keyEquivalent: String) {
        self.name = name
        self.toolTip = toolTip
        self.modifierFlags = modifierFlags
        self.keyEquivalent = keyEquivalent
    }

    public init(name: String, toolTip: String, modifierFlags: NSEvent.ModifierFlags, keyEquivalent: NSEvent.SpecialKey) {
        self.name = name
        self.toolTip = toolTip
        self.modifierFlags = modifierFlags
        self.keyEquivalent = Shortcut.printableKeyEquivalent(forSpecialKey: keyEquivalent.unicodeScalar) ?? ""
    }

    public let name: String
    public let toolTip: String
    public let modifierFlags: NSEvent.ModifierFlags
    public let keyEquivalent: String
}
