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
//  © 2014-2020 1024jp
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
    
    init(modifierMask: NSEvent.ModifierFlags, keyEquivalent: String) {
        self.modifierMask = {
            let modifierMask = modifierMask.intersection([.control, .option, .shift, .command])
            
            // -> For in case that a modifierMask taken from a menu item can lack Shift definition if the combination is "Shift + alphabet character" keys.
            if keyEquivalent.last?.isUppercase == true {
                return modifierMask.union(.shift)
            }
            
            return modifierMask
        }()
        
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
        return self.keyEquivalent.isEmpty && self.modifierMask.isEmpty
    }
    
    
    /// Whether key combination is valid for a shortcut.
    ///
    /// - Note: An empty shortcut is marked as invalid.
    var isValid: Bool {
        guard keyEquivalent.count == 1 else {
            return false
        }
        if let firstChar = self.keyEquivalent.utf16.first {
            if (0xF700...0xF8FF).contains(firstChar) || firstChar == 0x0D {
                return true
            }
        }
        let keys = ModifierKey.allCases.filter { self.modifierMask.contains($0.mask) }
        return !keys.isEmpty
    }
    
    
    
    // MARK: Protocols
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.modifierMask.rawValue)
        hasher.combine(self.keyEquivalent)
    }
    
    
    
    // MARK: Private Methods
    
    /// modifier keys string to display
    private var printableModifierMask: String {
        return ModifierKey.allCases
            .filter { self.modifierMask.contains($0.mask) }
            .map(\.symbol)
            .joined()
    }
    
    
    /// key equivalent to display
    private var printableKeyEquivalent: String {
        guard let scalar = self.keyEquivalent.unicodeScalars.first else { return "" }
        
        return Shortcut.printableKeyEquivalents[scalar] ?? self.keyEquivalent.uppercased()
    }
    
    
    /// table for characters that cannot be displayed as is with their printable substitutions
    private static let printableKeyEquivalents: [Unicode.Scalar: String] = [
        NSEvent.SpecialKey
        .upArrow: "↑",
        .downArrow: "↓",
        .leftArrow: "←",
        .rightArrow: "→",
        .f1: "F1",
        .f2: "F2",
        .f3: "F3",
        .f4: "F4",
        .f5: "F5",
        .f6: "F6",
        .f7: "F7",
        .f8: "F8",
        .f9: "F9",
        .f10: "F10",
        .f11: "F11",
        .f12: "F12",
        .f13: "F13",
        .f14: "F14",
        .f15: "F15",
        .f16: "F16",
        .delete: "⌦",
        .home: "↖",
        .end: "↘",
        .pageUp: "⇞",
        .pageDown: "⇟",
        .clearLine: "⌧",
        .help: "Help",
        .space: NSLocalizedString("Space", comment: "SwiftKeyBindings"),
        .tab: "⇥",
        .carriageReturn: "↩",
        .backspace: "⌫",  //  (delete backward)
        .enter: "⌅",
        .backTab: "⇤",
        .escape: "⎋",
    ].mapKeys(\.unicodeScalar)
    
    internal static func printableKeyEquivalent(forSpecialKey specialKey: Unicode.Scalar) -> String? {
        return printableKeyEquivalents[specialKey]
    }
    
}

private extension NSEvent.SpecialKey {
    static let space = Self(rawValue: 0x20)
    static let escape = Self(rawValue: 0x1b)
}


extension Shortcut: CustomStringConvertible {
    
    /// shortcut string to display
    var description: String {
        return self.printableModifierMask + self.printableKeyEquivalent
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


private extension Dictionary {
    
    /// Return a new dictionary containing the keys transformed by the given closure with the values of this dictionary.
    ///
    /// - Parameter transform: A closure that transforms a key. Every transformed key must be unique.
    /// - Returns: A dictionary containing transformed keys and the values of this dictionary.
    func mapKeys<T>(transform: (Key) throws -> T) rethrows -> [T: Value] {
        return try self.reduce(into: [:]) { $0[try transform($1.key)] = $1.value }
    }
    
    
    /// Return a new dictionary containing the keys transformed by the given keyPath with the values of this dictionary.
    ///
    /// - Parameter keyPath:  The keyPath to the value to transform key. Every transformed key must be unique.
    /// - Returns: A dictionary containing transformed keys and the values of this dictionary.
    func mapKeys<T>(_ keyPath: KeyPath<Key, T>) -> [T: Value] {
        return self.mapKeys { $0[keyPath: keyPath] }
    }
    
}
