//
//  AdvancedController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

final class AdvancedController: NSViewController {
    
    static let Identifier = "AdvancedPreferences"
    @IBOutlet weak var checkUpdatesCheckbox: NSButton!
    
    init() {
        super.init(nibName: "Advanced", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func resetUserDefaults(withCustomInitialURL initialURL: URL? = nil) {
        do {
            // register initial values
            if let initialURL = initialURL {
                // write local overrides for initial values
                let localOverrideURL = PreferencesController.initialValuesURL
                try? FileManager.default.removeItem(at: localOverrideURL)
                try FileManager.default.copyItem(at: initialURL, to: localOverrideURL)
                
                NotificationCenter.default.post(
                    name: PreferencesController.registerInitialValuesNotification,
                    object: nil,
                    userInfo: ["url": initialURL]
                )
            } else {
                // remove local overrides if presents
                let localOverrideURL = PreferencesController.initialValuesURL
                try? FileManager.default.removeItem(at: localOverrideURL)
                
                NotificationCenter.default.post(
                    name: PreferencesController.registerInitialValuesNotification,
                    object: nil
                )
            }
            
            // revert to initial values
            NSUserDefaultsController.shared.revertToInitialValues(nil)
            
            // clear restorable state
            AppDelegate.shared.tabService?
                .managedWindows.map({ $0.window })
                .forEach({ $0.isRestorable = false })
            
            // tell user to restart application
            actionRequiresRestart(nil)
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func resetUserDefaultsAction(_ sender: Any?) {
        let optionPressed = NSEvent.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.option)
        if !optionPressed {
            resetUserDefaults()
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.canCreateDirectories = false
            panel.showsHiddenFiles = false
            panel.allowsMultipleSelection = false
            panel.treatsFilePackagesAsDirectories = true
            panel.allowedFileTypes = ["plist"]
            let panelResponse = panel.runModal()
            if panelResponse == .OK, let selectedURL = panel.urls.first {
                resetUserDefaults(withCustomInitialURL: selectedURL)
            }
        }
    }
    
    private func resetTagDatabase(withCustomSchemaURL customSchemaURL: URL? = nil) {
        do {
            try TagListController.destoryPersistentStore()
            if let customSchemaURL = customSchemaURL {
                NotificationCenter.default.post(
                    name: TagListController.NotificationType.Name.tagPersistentStoreRequiresReloadNotification,
                    object: nil,
                    userInfo: ["url": customSchemaURL]
                )
            } else {
                NotificationCenter.default.post(
                    name: TagListController.NotificationType.Name.tagPersistentStoreRequiresReloadNotification,
                    object: nil
                )
            }
        } catch {
            presentError(error)
        }
    }
    
    @IBAction private func resetTagDatabaseAction(_ sender: Any?) {
        let optionPressed = NSEvent.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .contains(.option)
        if !optionPressed {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = NSLocalizedString("Reset Confirm", comment: "resetTagDatabaseAction(_:)")
            alert.informativeText = NSLocalizedString("Do you want to remove all user defined tags and reset the tag database to its initial state?\nThis operation cannot be undone.", comment: "resetTagDatabaseAction(_:)")
            alert.addButton(withTitle: NSLocalizedString("Confirm", comment: "resetTagDatabaseAction(_:)"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "resetTagDatabaseAction(_:)"))
            alert.beginSheetModal(for: view.window!) { [unowned self] resp in
                if resp == .alertFirstButtonReturn {
                    self.resetTagDatabase()
                }
            }
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.canCreateDirectories = false
            panel.showsHiddenFiles = false
            panel.allowsMultipleSelection = false
            panel.treatsFilePackagesAsDirectories = true
            panel.allowedFileTypes = ["plist"]
            let panelResponse = panel.runModal()
            if panelResponse == .OK, let selectedURL = panel.urls.first {
                resetTagDatabase(withCustomSchemaURL: selectedURL)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        #if APP_STORE
        checkUpdatesCheckbox.isEnabled = false
        checkUpdatesCheckbox.alphaValue = 0
        #else
        checkUpdatesCheckbox.isEnabled = true
        checkUpdatesCheckbox.alphaValue = 1
        #endif
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        #if !APP_STORE
        UserDefaults.standard[.checkUpdatesAutomatically] = AppDelegate.shared.sparkUpdater.automaticallyChecksForUpdates
        #endif
    }
    
    @IBAction private func actionRequiresRestart(_ sender: Any?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Restart required", comment: "actionRequiresRestart(_:)")
        alert.informativeText = NSLocalizedString("This option requires application to restart to complete the modification.", comment: "actionRequiresRestart(_:)")
        #if !APP_STORE
        alert.addButton(withTitle: NSLocalizedString("Restart", comment: "actionRequiresRestart(_:)"))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: "actionRequiresRestart(_:)"))
        alert.beginSheetModal(for: view.window!) { resp in
            if resp == .alertFirstButtonReturn {
                NSApp.relaunch(sender)
            }
        }
        #else
        alert.addButton(withTitle: NSLocalizedString("Quit Now", comment: "actionRequiresRestart(_:)"))
        alert.addButton(withTitle: NSLocalizedString("Later", comment: "actionRequiresRestart(_:)"))
        alert.beginSheetModal(for: view.window!) { resp in
            if resp == .alertFirstButtonReturn {
                NSApp.terminate(sender)
            }
        }
        #endif
    }
    
}

extension AdvancedController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return AdvancedController.Identifier
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Advanced", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Advanced")
    }
    
}
