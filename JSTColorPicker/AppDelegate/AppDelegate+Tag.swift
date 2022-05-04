//
//  AppDelegate+Tag.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/5/3.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    private var emptyTagSubMenuItems: [NSMenuItem] {
        let emptyItem = NSMenuItem(
            title: NSLocalizedString("No tag available.", comment: "emptyTagSubMenuItems"),
            action: nil,
            keyEquivalent: ""
        )
        emptyItem.isEnabled = false
        return [emptyItem]
    }
    
    func updateTagMenuItems(_ menu: NSMenu) {
        let isReadOnly: Bool = UserDefaults.standard[.disableTagEditing]
        tagsReadOnlyMenuItem.state = isReadOnly ? .on : .off
    }
    
    func updateTagSubMenuItems(_ menu: NSMenu) {
        guard let tagManager = firstRespondingWindowController?.tagManager else {
            menu.items = emptyTagSubMenuItems
            return
        }
        
        var itemIdx: Int = 0
        let selectedTags = tagManager.selectedTags
        var items = [NSMenuItem]()
        for arrangedTag in tagManager.arrangedTags {
            itemIdx += 1
            
            var keyEqu: String?
            if itemIdx < 10 { keyEqu = String(format: "%d", itemIdx % 10) }
            
            let item = NSMenuItem(
                title: arrangedTag.name,
                action: #selector(selectTagItemTapped(_:)),
                keyEquivalent: keyEqu ?? ""
            )
            
            item.representedObject = arrangedTag
            item.keyEquivalentModifierMask = [.option, .command]
            item.state = selectedTags.contains(arrangedTag) ? .on : .off
            item.identifier = NSUserInterfaceItemIdentifier("\(AppDelegate.tagIdentifierPrefix)\(arrangedTag.name)")
            item.tag = MainMenu.MenuItemTag.tags.rawValue
            item.toolTip = arrangedTag.toolTip
            
            items.append(item)
        }
        
        guard !items.isEmpty else {
            menu.items = emptyTagSubMenuItems
            return
        }
        
        let deselectItem = NSMenuItem(
            title: NSLocalizedString("Deselect All Tags", comment: "updateTagSubMenuItems(_:)"),
            action: #selector(deselectAllTagsItemTapped(_:)),
            keyEquivalent: "0"
        )
        
        deselectItem.keyEquivalentModifierMask = [.option, .command]
        deselectItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "deselect-all-tags")
        deselectItem.isEnabled = true
        
        menu.items = items + [
            NSMenuItem.separator(),
            deselectItem,
        ]
        
        MenuKeyBindingManager.shared.applyKeyBindingsToMenu(menu)
    }
    
    func updateTagDefinitionSubMenuItems(_ menu: NSMenu) {
        let showDefinitionItem = NSMenuItem(
            title: NSLocalizedString("Show Tag Definitions…", comment: "searchForDefinitionsAndUpdateContextMenu(_:)"),
            action: #selector(showDefinitionsMenuItemTapped(_:)),
            keyEquivalent: ""
        )
        
        showDefinitionItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "show-tag-definitions")
        showDefinitionItem.isEnabled = true
        showDefinitionItem.toolTip = NSLocalizedString("Show tag definitions in Finder.", comment: "updateTagDefinitionSubMenuItems(_:)")
        
        let items = TagListController.definitionMenuItems(withSelector: #selector(definitionMenuItemTapped(_:)))
        menu.items = items + [
            NSMenuItem.separator(),
            showDefinitionItem,
        ]
        
        MenuKeyBindingManager.shared.applyKeyBindingsToMenu(menu)
    }
    
    private static let tagIdentifierPrefix: String = "tag-"
    
    @objc
    @IBAction func definitionMenuItemTapped(_ sender: NSMenuItem) {
        if let definitionURL = sender.representedObject as? URL {
            do {
                try TagListController.destoryPersistentStore()
                NotificationCenter.default.post(
                    name: TagListController.NotificationType.Name.tagPersistentStoreRequiresReloadNotification,
                    object: nil,
                    userInfo: ["url": definitionURL]
                )
            } catch {
                presentError(error)
            }
        }
    }
    
    @objc
    @IBAction func toggleReadOnlyMode(_ sender: NSMenuItem) {
        let isReadOnly: Bool = UserDefaults.standard[.disableTagEditing]
        UserDefaults.standard[.disableTagEditing] = !isReadOnly
    }
    
    @objc
    @IBAction func showDefinitionsMenuItemTapped(_ sender: NSMenuItem) {
        let url = TagListController.definitionRootURL
        guard url.isDirectory else {
            presentError(GenericError.notDirectory(url: url))
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @objc
    @IBAction func deselectAllTagsItemTapped(_ sender: NSMenuItem) {
        _ = firstRespondingWindowController?.tagManager.removeAllSelectedTags()
    }
    
    @objc
    @IBAction func selectTagItemTapped(_ sender: NSMenuItem) {
        guard let tagManager = firstRespondingWindowController?.tagManager else {
            return
        }
        
        if let tag = sender.representedObject as? Tag {
            if tagManager.selectedTags.contains(tag) {
                _ = tagManager.removeSelectedTags([tag])
            } else {
                _ = tagManager.addSelectedTags([tag])
            }
        }
    }
    
    func validateTagMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.menu == tagSubMenu {
            return true
        }
        else if menuItem.menu == tagDefinitionSubMenu {
            return true
        }
        return true
    }
    
}

