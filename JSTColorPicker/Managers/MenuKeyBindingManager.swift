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
        
        _defaultKeyBindings = Set(Self.scanMenuKeyBindingRecurrently(menu: mainMenu))
        
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
        self.applyKeyBindingsToMainMenu()
    }
    
    
    
    // MARK: Public Methods
    
    /// re-apply keyboard short cut to all menu items
    func applyKeyBindingsToMainMenu() {
        
        let mainMenu = NSApp.mainMenu!
        applyKeyBindingsToMenu(mainMenu)
    }
    
    func applyKeyBindingsToMenu(_ menu: NSMenu) {
        
        // at first, clear all current short cut sttings at first
        self.clearMenuKeyBindingRecurrently(menu: menu)
        
        // then apply the latest settings
        self.applyMenuKeyBindingRecurrently(menu: menu)
        
        menu.update()
    }
    
    /// keyEquivalent and modifierMask for passed-in selector
    func shortcut(
        forAssociatedIdentifier associatedIdentifier: String,
        forAssociatedTag associatedTag: Int,
        forAction action: Selector
    ) -> Shortcut {
        
        let shortcut = self.shortcut(
            forAssociatedIdentifier: associatedIdentifier,
            forAssociatedTag: associatedTag,
            forAction: action,
            defaults: false
        )
        
        return shortcut.isValid ? shortcut : .none
    }
    
    
    
    // MARK: Private Methods
    
    /// return key bindings for selector
    private func shortcut(
        forAssociatedIdentifier associatedIdentifier: String,
        forAssociatedTag associatedTag: Int,
        forAction action: Selector,
        defaults usesDefaults: Bool
    ) -> Shortcut {
        
        let keyBindings = usesDefaults ? self.defaultKeyBindings : self.keyBindings
        let keyBinding = keyBindings.first {
            $0.associatedIdentifier == associatedIdentifier
            && $0.associatedTag == associatedTag
            && $0.action == action
        }
        
        return keyBinding?.shortcut ?? .none
    }
    
    
    /// whether shortcut of menu item is allowed to modify
    private static func allowsModifying(_ menuItem: NSMenuItem) -> Bool {
        
        // specific item types
        if menuItem.isSeparatorItem ||
            menuItem.isAlternate ||
            (menuItem.isHidden && !menuItem.allowsKeyEquivalentWhenHidden) ||
            menuItem.keyEquivalentModifierMask.contains(.function) ||
            menuItem.title.isEmpty {
            return false
        }
        
        // specific tags
        if let tag = MainMenu.MenuItemTag(rawValue: menuItem.tag) {
            switch tag {
                case .services,
                     .recentDocumentsDirectory,
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
             #selector(NSApplication.showHelp(_:)),
             #selector(NSApplication.orderFrontCharacterPalette): // = "Emoji & Symbols"
            return false
            
        // window tabbing actions
        // -> Because they cannot be set correctly.
        case #selector(NSDocument.saveAs(_:)),
             #selector(NSDocument.revertToSaved(_:)),
             #selector(NSWindow.selectNextTab(_:)),
             #selector(NSWindow.selectPreviousTab(_:)),
             #selector(NSWindow.moveTabToNewWindow(_:)),
             #selector(NSWindow.mergeAllWindows(_:)):
            return false
            
        default: break
        }
        
        return true
    }
    
    
    /// Allow modifying only menu items existed at launch .
    ///
    /// - Parameter menuItem: The menu item to check.
    /// - Returns: Whether the given menu item can be modified by users.
    private func allowsModifying(_ menuItem: NSMenuItem) -> Bool {
        
        guard Self.allowsModifying(menuItem) else { return false }
        
        switch menuItem.action {
            case #selector(NSMenu.submenuAction), .none:
                return true
            case let .some(action):
                return self.defaultKeyBindings.map(\.action).contains(action)
        }
    }
    
    
    /// scan all key bindings as well as selector name in passed-in menu
    private class func scanMenuKeyBindingRecurrently(menu: NSMenu) -> [KeyBinding] {
        
        menu.items
            .filter(Self.allowsModifying)
            .flatMap { menuItem -> [KeyBinding] in
                if let submenu = menuItem.submenu {
                    return self.scanMenuKeyBindingRecurrently(menu: submenu)
                }
                
                guard let action = menuItem.action else { return [] }
                
                let associatedTag = menuItem.tag
                var associatedIdentifier = menuItem.identifier?.rawValue ?? ""
                if associatedIdentifier.hasPrefix("_NS:") {
                    associatedIdentifier = ""
                }
                
                let shortcut = Shortcut(
                    modifierMask: menuItem.keyEquivalentModifierMask,
                    keyEquivalent: menuItem.keyEquivalent
                )
                
                return [KeyBinding(
                    name: menuItem.title,
                    associatedIdentifier: associatedIdentifier,
                    associatedTag: associatedTag,
                    action: action,
                    shortcut: shortcut.isValid ? shortcut : nil
                )]
            }
    }
    
    
    /// clear keyboard shortcuts in the passed-in menu
    private func clearMenuKeyBindingRecurrently(menu: NSMenu) {
        
        menu.items
            .filter(self.allowsModifying)
            .forEach { menuItem in
                if let submenu = menuItem.submenu {
                    return self.clearMenuKeyBindingRecurrently(menu: submenu)
                }
                
                menuItem.keyEquivalent = ""
                menuItem.keyEquivalentModifierMask = []
            }
    }
    
    
    /// apply current keyboard short cut settings to the passed-in menu
    private func applyMenuKeyBindingRecurrently(menu: NSMenu) {
        
        menu.items
            .filter(self.allowsModifying)
            .forEach { menuItem in
                if let submenu = menuItem.submenu {
                    return self.applyMenuKeyBindingRecurrently(menu: submenu)
                }
                
                guard let action = menuItem.action else { return }
                
                let associatedTag = menuItem.tag
                var associatedIdentifier = menuItem.identifier?.rawValue ?? ""
                if associatedIdentifier.hasPrefix("_NS:") {
                    associatedIdentifier = ""
                }
                
                let shortcut = self.shortcut(
                    forAssociatedIdentifier: associatedIdentifier,
                    forAssociatedTag: associatedTag,
                    forAction: action
                )
                
                // apply only if both keyEquivalent and modifierMask exist
                guard shortcut.isValid else { return }
                
                menuItem.keyEquivalent = shortcut.keyEquivalent
                menuItem.keyEquivalentModifierMask = shortcut.modifierMask
            }
    }
    
    
    /// read key bindings from the menu and create an array data for outlineView in preferences
    private func outlineTree(menu: NSMenu, defaults usesDefaults: Bool) -> [NSTreeNode] {
        
        menu.items
            .filter(self.allowsModifying)
            .compactMap { menuItem in
                if let submenu = menuItem.submenu {
                    let node = NamedTreeNode(name: menuItem.title, representedObject: menuItem.identifier)
                    let subtree = self.outlineTree(menu: submenu, defaults: usesDefaults)
                    
                    guard !subtree.isEmpty else { return nil }  // ignore empty submenu
                    
                    node.mutableChildren.addObjects(from: subtree)
                    return node
                }
                
                guard let action = menuItem.action else { return nil }
                
                var associatedIdentifier = menuItem.identifier?.rawValue ?? ""
                if associatedIdentifier.hasPrefix("_NS:") {
                    associatedIdentifier = ""
                }
                let associatedTag = menuItem.tag
                
                let defaultShortcut = self.shortcut(
                    forAssociatedIdentifier: associatedIdentifier,
                    forAssociatedTag: associatedTag,
                    forAction: action,
                    defaults: true
                )
                
                let shortcut = usesDefaults
                    ? defaultShortcut
                    : Shortcut(
                        modifierMask: menuItem.keyEquivalentModifierMask,
                        keyEquivalent: menuItem.keyEquivalent
                    )
                
                let item = KeyBindingItem(
                    name: menuItem.title,
                    associatedIdentifier: associatedIdentifier,
                    associatedTag: associatedTag,
                    action: action,
                    shortcut: shortcut,
                    defaultShortcut: defaultShortcut
                )
                
                return NamedTreeNode(name: menuItem.title, representedObject: item)
            }
    }
    
}
