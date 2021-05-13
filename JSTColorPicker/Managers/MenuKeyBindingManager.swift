//
//  MenuKeyBindingManager.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2016-06-22.
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

import Cocoa

final class MenuKeyBindingManager: KeyBindingManager {
    
    // MARK: Public Properties
    
    static let shared = MenuKeyBindingManager()
    
    
    // MARK: Private Properties
    
    private let _defaultKeyBindings: Set<KeyBinding>
    
    
    
    // MARK: -
    // MARK: Lifecycle
    
    override private init() {
        
        guard let mainMenu = NSApp.mainMenu else {
            fatalError("MenuKeyBindingManager should be initialized after Main.storyboard is loaded.")
        }
        
        _defaultKeyBindings = Self.scanMenuKeyBindingRecurrently(menu: mainMenu)
        
        super.init()
    }
    
    
    
    // MARK: Key Binding Manager Methods
    
    /// name of file to save custom key bindings in the plist file form (without extension)
    override var settingFileName: String {
        
        return "Shortcuts"
    }
    
    
    /// default key bindings
    override var defaultKeyBindings: Set<KeyBinding> {
        
        return _defaultKeyBindings
    }
    
    
    /// create a KVO-compatible collection for outlineView in preferences from the key binding setting
    ///
    /// - Parameter usesDefaults: `true` for default setting and `false` for the current setting.
    override func outlineTree(defaults usesDefaults: Bool) -> [NSTreeNode] {
        
        return self.outlineTree(menu: NSApp.mainMenu!, defaults: usesDefaults)
    }
    
    
    /// save passed-in key binding settings
    override func saveKeyBindings(outlineTree: [NSTreeNode]) throws {
        
        try super.saveKeyBindings(outlineTree: outlineTree)
        
        // apply new settings to the menu
        self.applyKeyBindingsToMainMenu(needsUpdate: true)
    }
    
    
    /// validate new key spec chars are settable
    override func validate(shortcut: Shortcut, oldShortcut: Shortcut?) throws {
        
        try super.validate(shortcut: shortcut, oldShortcut: oldShortcut)
        
        // command key existance check
        if !shortcut.isEmpty, !shortcut.modifierMask.contains(.command) {
            throw InvalidKeySpecCharactersError(kind: .lackingCommandKey, shortcut: shortcut)
        }
    }
    
    
    
    // MARK: Public Methods
    
    /// scan key bindings in main menu and store them as default values
    ///
    /// This method should be called before main menu is modified.
    func scanDefaultMenuKeyBindings() {
        
        // do nothing
        // -> Actually, `defaultMenuKeyBindings` is already scanned in `init`.
    }
    
    
    /// re-apply keyboard short cut to all menu items
    func applyKeyBindingsToMainMenu(needsUpdate update: Bool) {
        applyKeyBindingsToMenu(NSApp.mainMenu!, needsUpdate: update)
    }
    
    
    /// re-apply keyboard short cut to all menu items
    func applyKeyBindingsToMenu(_ menu: NSMenu, needsUpdate update: Bool) {
        // at first, clear all current short cut sttings at first
        self.clearMenuKeyBindingRecurrently(menu: menu)
        
        // then apply the latest settings
        self.applyMenuKeyBindingRecurrently(menu: menu)
        
        if update {
            menu.update()
        }
    }
    
    /// keyEquivalent and modifierMask for passed-in selector
    func shortcut(
        forAction action: Selector,
        forAssociatedIdentifier associatedIdentifier: String?,
        forAssociatedTag associatedTag: Int
    ) -> Shortcut {
        let shortcut = self.shortcut(
            forAction: action,
            forAssociatedIdentifier: associatedIdentifier,
            forAssociatedTag: associatedTag,
            defaults: false
        )
        
        guard !shortcut.isEmpty
        else {
            return .none
        }
        
        return shortcut
    }
    
    
    
    // MARK: Private Methods
    
    /// return key bindings for selector
    private func shortcut(
        forAction action: Selector,
        forAssociatedIdentifier associatedIdentifier: String?,
        forAssociatedTag associatedTag: Int,
        defaults usesDefaults: Bool
    ) -> Shortcut {
        let keyBindings = usesDefaults ? self.defaultKeyBindings : self.keyBindings
        var definition: KeyBinding?
        if associatedTag > 0 {
            definition = keyBindings.first { $0.associatedTag == associatedTag }
        } else if let associatedIdentifier = associatedIdentifier, !associatedIdentifier.isEmpty, !associatedIdentifier.hasPrefix("_NS:")
        {
            definition = keyBindings.first { $0.associatedIdentifier == associatedIdentifier }
        } else {
            definition = keyBindings.first { $0.action == action }
        }
        return definition?.shortcut ?? .none
    }
    
    
    /// whether shortcut of menu item is allowed to modify
    private static func allowsModifying(_ menuItem: NSMenuItem) -> Bool {
        
        // specific item types
        if menuItem.isSeparatorItem ||
            menuItem.isAlternate ||
            (menuItem.isHidden && !menuItem.allowsKeyEquivalentWhenHidden) ||
            menuItem.title.isEmpty {
            return false
        }
        
        // specific tags
        if let tag = MainMenu.MenuItemTag(rawValue: menuItem.tag) {
            switch tag {
                case .services,
                     .recentDocuments,
                     .sharingService,
                     .devices,
                     .templates:
                    return false
            }
        }
        
        // specific private actions
        if menuItem.action?.description == "_share:" {
            return false
        }
        
        // specific actions
        switch menuItem.action {
        case #selector(NSWindow.makeKeyAndOrderFront),
             #selector(NSApplication.orderFrontCharacterPalette):  // = "Emoji & Symbols"
            return false
            
        // window tabbing actions
        // -> Because they cannot be set correctly.
        case #selector(NSDocument.revertToSaved(_:)),
             #selector(NSWindow.selectNextTab(_:)),
             #selector(NSWindow.selectPreviousTab(_:)),
             #selector(NSWindow.moveTabToNewWindow(_:)),
             #selector(NSWindow.mergeAllWindows(_:)):
            return false
            
        default: break
        }
        
        return true
    }
    
    
    /// scan all key bindings as well as selector name in passed-in menu
    private class func scanMenuKeyBindingRecurrently(menu: NSMenu) -> Set<KeyBinding> {
        
        let keyBindings: [KeyBinding] = menu.items.lazy
            .filter(self.allowsModifying)
            .map { menuItem -> [KeyBinding] in
                if let submenu = menuItem.submenu {
                    return self.scanMenuKeyBindingRecurrently(menu: submenu).sorted()
                }
                
                guard let action = menuItem.action else { return [] }
                
                let shortcut = Shortcut(
                    modifierMask: menuItem.keyEquivalentModifierMask,
                    keyEquivalent: menuItem.keyEquivalent
                )
                
                guard shortcut.isValid else { return [] }
                
                return [
                    KeyBinding(
                        action: action,
                        associatedIdentifier: menuItem.identifier?.rawValue ?? "",
                        associatedTag: menuItem.tag,
                        shortcut: shortcut
                    )
                ]
            }
            .flatMap { $0 }
        
        return Set(keyBindings)
    }
    
    
    /// clear keyboard shortcuts in the passed-in menu
    private func clearMenuKeyBindingRecurrently(menu: NSMenu) {
        
        menu.items.lazy
            .filter(Self.allowsModifying)
            .forEach { menuItem in
                if let submenu = menuItem.submenu {
                    self.clearMenuKeyBindingRecurrently(menu: submenu)
                    return
                }
                
                menuItem.keyEquivalent = ""
                menuItem.keyEquivalentModifierMask = []
            }
    }
    
    
    /// apply current keyboard short cut settings to the passed-in menu
    private func applyMenuKeyBindingRecurrently(menu: NSMenu) {
        
        menu.items.lazy
            .filter(Self.allowsModifying)
            .forEach { menuItem in
                if let submenu = menuItem.submenu {
                    self.applyMenuKeyBindingRecurrently(menu: submenu)
                    return
                }
                
                guard let action = menuItem.action else { return }
                
                let shortcut = self.shortcut(
                    forAction: action,
                    forAssociatedIdentifier: menuItem.identifier?.rawValue,
                    forAssociatedTag: menuItem.tag
                )
                
                // apply only if both keyEquivalent and modifierMask exist
                guard !shortcut.isEmpty
                else {
                    return
                }
                
                menuItem.keyEquivalent = shortcut.keyEquivalent
                menuItem.keyEquivalentModifierMask = shortcut.modifierMask
            }
    }
    
    
    /// read key bindings from the menu and create an array data for outlineView in preferences
    private func outlineTree(menu: NSMenu, defaults usesDefaults: Bool) -> [NSTreeNode] {
        
        return menu.items.lazy
            .filter(Self.allowsModifying)
            .compactMap { menuItem in
                if let submenu = menuItem.submenu {
                    let node = NamedTreeNode(name: menuItem.title)
                    let subtree = self.outlineTree(menu: submenu, defaults: usesDefaults)
                    
                    guard !subtree.isEmpty else { return nil }  // ignore empty submenu
                    
                    node.mutableChildren.addObjects(from: subtree)
                    return node
                }
                
                guard let action = menuItem.action else { return nil }
                
                let defaultShortcut = self.shortcut(
                    forAction: action,
                    forAssociatedIdentifier: menuItem.identifier?.rawValue,
                    forAssociatedTag: menuItem.tag,
                    defaults: true
                )
                
                let shortcut = usesDefaults
                    ? defaultShortcut
                    : Shortcut(
                        modifierMask: menuItem.keyEquivalentModifierMask,
                        keyEquivalent: menuItem.keyEquivalent
                    )
                
                let item = KeyBindingItem(
                    action: action,
                    associatedIdentifier: menuItem.identifier?.rawValue ?? "",
                    associatedTag: menuItem.tag,
                    shortcut: shortcut,
                    defaultShortcut: defaultShortcut
                )
                
                return NamedTreeNode(
                    name: menuItem.title,
                    representedObject: item
                )
            }
    }
    
}
