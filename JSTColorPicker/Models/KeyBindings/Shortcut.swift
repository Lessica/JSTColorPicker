//
//  Shortcut.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2014-04-20.
//
//  ---------------------------------------------------------------------------
//
//  © 2004-2007 nakamuxu
//  © 2014-2022 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import AppKit.NSEvent

/// Modifier keys for keyboard shortcut.
///
/// The order of cases (control, option, shift, and command) is determined in the HIG.
enum ModifierKey: CaseIterable {
    
    case control
    case option
    case shift
    case command
    
    
    static var mask: NSEvent.ModifierFlags {
        
        self.allCases.reduce(into: []) { $0.formUnion($1.mask) }
    }
    
    
    var mask: NSEvent.ModifierFlags {
        
        switch self {
            case .control: return .control
            case .option:  return .option
            case .shift:   return .shift
            case .command: return .command
        }
    }
    
    
    /// printable symbol
    var symbol: String {
        
        switch self {
            case .control: return "^"
            case .option:  return "⌥"
            case .shift:   return "⇧"
            case .command: return "⌘"
        }
    }
    
    
    /// storeble symbol
    var keySpecChar: String {
        
        switch self {
            case .control: return "^"
            case .option:  return "~"
            case .shift:   return "$"
            case .command: return "@"
        }
    }
    
}



struct Shortcut: Hashable {
    
    let modifierMask: NSEvent.ModifierFlags
    let keyEquivalent: String
    
    
    static let none = Shortcut(modifierMask: [], keyEquivalent: "")
    
    /// Some special keys allowed to asign without modifier keys.
    private static let singleKeys: [NSEvent.SpecialKey] = [
        .home,
        .end,
        .pageUp,
        .pageDown,
        .backspace,
        .f1, .f2, .f3, .f4,
        .f5, .f6, .f7, .f8,
        .f9, .f10, .f11, .f12,
        .f13, .f14, .f15, .f16,
        .f17, .f18, .f19, .f20,
        .f21, .f22, .f23, .f24,
        .f25, .f26, .f27, .f28,
        .f29, .f30, .f31, .f32,
        .f33, .f34, .f35
    ]
    
    
    init(modifierMask: NSEvent.ModifierFlags, keyEquivalent: String) {
        
        // -> For in case that a modifierMask taken from a menu item can lack Shift definition if the combination is "Shift + alphabet character" keys.
        let needsShift = keyEquivalent.last?.isUppercase == true
        
        self.modifierMask = modifierMask
            .intersection(ModifierKey.mask)
            .union(needsShift ? .shift : [])
        self.keyEquivalent = keyEquivalent
    }
    
    
    init(keySpecChars: String) {
        
        guard let keyEquivalent = keySpecChars.last else {
            self.init(modifierMask: [], keyEquivalent: "")
            return
        }
        
        let modifierCharacters = keySpecChars.dropLast()
        let modifierMask = ModifierKey.allCases
            .filter { modifierCharacters.contains($0.keySpecChar) }
            .reduce(into: NSEvent.ModifierFlags()) { $0.formUnion($1.mask) }
        
        self.init(modifierMask: modifierMask, keyEquivalent: String(keyEquivalent))
    }
    
    
    init?(keyDownEvent event: NSEvent) {
        
        assert(event.type == .keyDown)
        
        guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers else { return nil }
        
        // correct Backspace and Forward Delete keys
        //  -> Backspace:      The key above the Return.
        //     Forward Delete: The key with printed "Delete" where next to the ten key pad.
        // cf. https://developer.apple.com/documentation/appkit/nsmenuitem/1514842-keyequivalent
        let keyEquivalent: String
        switch event.specialKey {
            case NSEvent.SpecialKey.delete:
                keyEquivalent = String(NSEvent.SpecialKey.backspace.unicodeScalar)
            case NSEvent.SpecialKey.deleteForward:
                keyEquivalent = String(NSEvent.SpecialKey.delete.unicodeScalar)
            default:
                keyEquivalent = charactersIgnoringModifiers
        }
        
        // remove unwanted Shift
        let ignoresShift = "`~!@#$%^&()_{}|\":<>?=/*-+.'".contains(keyEquivalent)
        let modifierMask = event.modifierFlags
            .intersection(ModifierKey.mask)
            .subtracting(ignoresShift ? .shift : [])
        
        self.init(modifierMask: modifierMask, keyEquivalent: keyEquivalent)
    }
    
    
    /// unique string to store in plist
    var keySpecChars: String {
        
        let modifierCharacters = ModifierKey.allCases
            .filter { self.modifierMask.contains($0.mask) }
            .map(\.keySpecChar)
            .joined()
        
        return modifierCharacters + self.keyEquivalent
    }
    
    
    /// whether the shortcut key is empty
    var isEmpty: Bool {
        
        self.modifierMask.isEmpty && self.keyEquivalent.isEmpty
    }
    
    
    /// Whether key combination is valid for a shortcut.
    ///
    /// - Note: An empty shortcut is marked as invalid.
    var isValid: Bool {
        
        if Self.singleKeys.map(\.unicodeScalar).map(String.init).contains(self.keyEquivalent) {
            return true
        }
        
        return !self.modifierMask.isEmpty && self.keyEquivalent.count == 1
    }
    
    
    
    // MARK: Protocols
    
    func hash(into hasher: inout Hasher) {
        
        hasher.combine(self.modifierMask.rawValue)
        hasher.combine(self.keyEquivalent)
    }
    
    
    
    // MARK: Private Methods
    
    /// modifier keys string to display
    private var modifierMaskSymbols: [String] {
        
        ModifierKey.allCases
            .filter { self.modifierMask.contains($0.mask) }
            .map(\.symbol)
    }
    
    
    /// key equivalent to display
    private var keyEquivalentSymbol: String {
        
        guard let scalar = self.keyEquivalent.unicodeScalars.first else { return "" }
        
        return Self.keyEquivalentSymbols[scalar]
            ?? self.keyEquivalent.uppercased()
    }
    
    
    /// table for key equivalent that have special symbols to display.
    private static let keyEquivalentSymbols: [Unicode.Scalar: String] = [
        NSEvent.SpecialKey
        .upArrow: "↑",
        .downArrow: "↓",
        .leftArrow: "←",
        .rightArrow: "→",
        .delete: "⌦",
        .backspace: "⌫",
        .home: "↖",
        .end: "↘",
        .pageUp: "⇞",
        .pageDown: "⇟",
        .clearLine: "⌧",
        .carriageReturn: "↩",
        .enter: "⌅",
        .tab: "⇥",
        .backTab: "⇤",
        .escape: "⎋",
        .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4",
        .f5: "F5", .f6: "F6", .f7: "F7", .f8: "F8",
        .f9: "F9", .f10: "F10", .f11: "F11", .f12: "F12",
        .f13: "F13", .f14: "F14", .f15: "F15", .f16: "F16",
        .f17: "F17", .f18: "F18", .f19: "F19", .f20: "F20",
        .f21: "F21", .f22: "F22", .f23: "F23", .f24: "F24",
        .f25: "F25", .f26: "F26", .f27: "F27", .f28: "F28",
        .f29: "F29", .f30: "F30", .f31: "F31", .f32: "F32",
        .f33: "F33", .f34: "F34", .f35: "F35",
        .help: "Help",
        .space: NSLocalizedString("Space", comment: "SwiftKeyBindings"),
    ].mapKeys(\.unicodeScalar)
    
    internal static func printableKeyEquivalent(forSpecialKey specialKey: Unicode.Scalar?) -> String? {
        guard let specialKey = specialKey else { return nil }
        return keyEquivalentSymbols[specialKey]
    }
    
}

private extension NSEvent.SpecialKey {
    
    static let space = Self(rawValue: 0x20)
    static let escape = Self(rawValue: 0x1b)
}


extension Shortcut: CustomStringConvertible {
    
    /// shortcut string to display
    var description: String {
        
        (self.modifierMaskSymbols + [self.keyEquivalentSymbol]).joined(separator: .thinSpace)
    }
    
}


extension Shortcut: Codable {
    
    init(from decoder: Decoder) throws {
        
        let container = try decoder.singleValueContainer()
        
        self.init(keySpecChars: try container.decode(String.self))
    }
    
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.singleValueContainer()
        
        try container.encode(self.keySpecChars)
    }
    
}
