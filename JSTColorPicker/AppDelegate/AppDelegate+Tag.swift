//
//  AppDelegate+Tag.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/5/3.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    func updateTagMenuItems(_ menu: NSMenu) {
        let isReadOnly: Bool = UserDefaults.standard[.disableTagEditing]
        tagsReadOnlyMenuItem.state = isReadOnly ? .on : .off
    }
    
    func updateTagSubMenuItems(_ menu: NSMenu) {
        
    }
    
    func updateTagDefinitionSubMenuItems(_ menu: NSMenu) {
        menu.items = TagListController.definitionMenuItems(withSelector: #selector(definitionMenuItemTapped(_:)))
    }
    
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
    
    func validateTagMenuItem(_ menuItem: NSMenuItem) -> Bool {
        debugPrint(menuItem)
        if menuItem.menu == tagDefinitionSubMenu {
            return true
        }
        return true
    }
    
}

