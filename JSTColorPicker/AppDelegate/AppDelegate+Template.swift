//
//  AppDelegate+Template.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    internal func applicationLoadTemplatesIfNeeded() {
        let searchPaths = [
            Bundle.main.resourcePath!,
            Bundle(identifier: "com.jst.LuaC")!.resourcePath!,
            Bundle(identifier: "com.jst.LuaC")!.resourceURL!
                .appendingPathComponent("Modules.bundle", isDirectory: true).path,
            TemplateManager.templateRootURL.path
        ]
        setenv("LUA_PATH", searchPaths.reduce("") { $0 + $1 + "/?.lua;" }, 1)
        setenv("LUA_CPATH", searchPaths.reduce("") { $0 + $1 + "/?.so;" }, 1)
        if TemplateManager.shared.numberOfTemplates == 0 {
            TemplateManager.exampleTemplateURLs.forEach { (exampleTemplateURL) in
                let exampleTemplateName: String
                if exampleTemplateURL.pathExtension == "bundle" {
                    exampleTemplateName = exampleTemplateURL.deletingPathExtension().lastPathComponent
                } else {
                    exampleTemplateName = exampleTemplateURL.lastPathComponent
                }
                let newExampleTemplateURL = TemplateManager.templateRootURL.appendingPathComponent(exampleTemplateName)
                try? FileManager.default.copyItem(at: exampleTemplateURL, to: newExampleTemplateURL)
            }
            try? TemplateManager.shared.reloadTemplates()
        }
    }
    
    
    // MARK: - Template Actions
    
    private static let templateIdentifierPrefix                 : String = "template-"
    
    @objc
    @IBAction private func showTemplates(_ sender: Any?) {
        applicationLoadTemplatesIfNeeded()
        let url = TemplateManager.templateRootURL
        guard url.isDirectory else {
            presentError(GenericError.notDirectory(url: url))
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    @objc
    @IBAction private func showTemplatesMenuItemTapped(_ sender: NSMenuItem) {
        showTemplates(sender)
    }
    
    @objc
    @IBAction private func showLogs(_ sender: Any?) {
        do {
            try openConsole()
        } catch {
            presentError(error)
        }
    }
    
    @objc
    @IBAction private func showLogsMenuItemTapped(_ sender: NSMenuItem) {
        showLogs(sender)
    }
    
    @objc
    @IBAction func selectTemplateItemTapped(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? Template else { return }
        TemplateManager.shared.selectedTemplate = template
    }
    
    @objc
    @IBAction func reloadTemplatesItemTapped(_ sender: NSMenuItem) {
        do {
            try TemplateManager.shared.reloadTemplates()
        } catch {
            presentError(error)
        }
    }
    
    
    // MARK: - Template Menu Items
    
    internal func updateTemplateSubMenuItems(_ menu: NSMenu) {
        var itemIdx: Int = 0
        let items = TemplateManager.shared.templates
            .compactMap({ [weak self] (template) -> NSMenuItem in
                itemIdx += 1
                
                var keyEqu: String?
                if itemIdx < 10 { keyEqu = String(format: "%d", itemIdx % 10) }
                
                let item = NSMenuItem(
                    title: "\(template.name) (\(template.version))",
                    action: #selector(self?.selectTemplateItemTapped(_:)),
                    keyEquivalent: keyEqu ?? ""
                )
                
                item.target = self
                item.representedObject = template
                item.keyEquivalentModifierMask = [.control, .command]
                item.state = template.uuid == TemplateManager.shared.selectedTemplate?.uuid ? .on : .off
                item.identifier = NSUserInterfaceItemIdentifier("\(AppDelegate.templateIdentifierPrefix)\(template.uuid.uuidString)")
                item.tag = MainMenu.MenuItemTag.templates.rawValue
                
                return item
            })
        
        let separatorItem = NSMenuItem.separator()
        let reloadTemplatesItem = NSMenuItem(
            title: NSLocalizedString("Reload All Templates", comment: "updateTemplateSubMenuItems(_:)"),
            action: #selector(reloadTemplatesItemTapped(_:)),
            keyEquivalent: "0"
        )
        
        reloadTemplatesItem.target = self
        reloadTemplatesItem.keyEquivalentModifierMask = [.control, .command]
        reloadTemplatesItem.identifier = NSUserInterfaceItemIdentifier(rawValue: "reload-all-templates")
        reloadTemplatesItem.isEnabled = true
        reloadTemplatesItem.toolTip = NSLocalizedString("Reload template scripts from file system.", comment: "updateTemplateSubMenuItems(_:)")
        
        if items.count > 0 {
            templateSubMenu.items = items + [ separatorItem, reloadTemplatesItem ]
        } else {
            let emptyItem = NSMenuItem(
                title: NSLocalizedString("No template available.", comment: "updateTemplateSubMenuItems(_:)"),
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            templateSubMenu.items = [ emptyItem, separatorItem, reloadTemplatesItem ]
        }
        
        MenuKeyBindingManager.shared.applyKeyBindingsToMenu(templateSubMenu)
    }
    
    func validateTemplateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(reloadTemplatesItemTapped(_:))
        {
            let hasAttachedSheet = firstRespondingWindowController?.hasAttachedSheet ?? false
            guard !hasAttachedSheet else { return false }
            return !TemplateManager.shared.isLocked
        }
        else if menuItem.action == #selector(selectTemplateItemTapped(_:))
        {
            let hasAttachedSheet = firstRespondingWindowController?.hasAttachedSheet ?? false
            guard !hasAttachedSheet else { return false }
            guard let template = menuItem.representedObject as? Template, template.isEnabled else { return false }
            
            let enabled = Template.currentPlatformVersion.isVersion(greaterThanOrEqualTo: template.platformVersion)
            
            if enabled {
                menuItem.toolTip = """
\(template.name) (\(template.version))
by \(template.author ?? "Unknown")
------
\(template.userDescription ?? "")
"""
            }
            else {
                menuItem.toolTip = Template.Error
                    .unsatisfiedPlatformVersion(version: template.platformVersion).failureReason
            }
            
            return enabled
        }
        else if menuItem.action == #selector(showTemplatesMenuItemTapped(_:))
                    || menuItem.action == #selector(showLogsMenuItemTapped(_:))
        {
            return true
        }
        return false
    }
    
}

