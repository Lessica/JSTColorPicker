//
//  ShortcutGuide+Ext.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/3/30.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa
import ShortcutGuide

extension ShortcutItem {

    init?(menuItem: NSMenuItem) {
        guard !menuItem.isSeparatorItem && !menuItem.keyEquivalent.isEmpty
        else { return nil }
        let keyString = menuItem.keyEquivalent
        var modifierFlags = menuItem.keyEquivalentModifierMask
        if keyString.first?.isUppercase ?? false {
            modifierFlags.formUnion(.shift)
        }
        self.init(
            name: menuItem.title,
            keyString: ShortcutItem.convertKeyStringToVisibleReplacement(keyString),
            toolTip: menuItem.toolTip ?? "",
            modifierFlags: modifierFlags
        )
    }

    private static func convertKeyStringToVisibleReplacement(_ string: String) -> String {
        var uppercasedString = string.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current).uppercased()
        if uppercasedString == "\r" || uppercasedString == "\n" {
            uppercasedString = ShortcutItem.KeyboardCharacter.return.rawValue
        } else if uppercasedString == "\u{8}" {
            uppercasedString = ShortcutItem.KeyboardCharacter.delete.rawValue
        }
        return uppercasedString
    }

}
