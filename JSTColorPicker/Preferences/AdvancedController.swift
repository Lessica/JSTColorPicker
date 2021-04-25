//
//  AdvancedController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class AdvancedController: NSViewController {
    
    @IBOutlet weak var checkUpdatesCheckbox: NSButton!
    
    init() {
        super.init(nibName: "Advanced", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func resetUserDefaultsAction(_ sender: NSButton) {
        NSUserDefaultsController.shared.revertToInitialValues(sender)
        // clear restorable state
        AppDelegate.shared.tabService?
            .managedWindows.map({ $0.window })
            .forEach({ $0.isRestorable = false })
        actionRequiresRestart(sender)
    }
    
    private func resetTagDatabase() {
        do {
            try TagListController.destoryPersistentStore()
            NotificationCenter.default.post(
                name: TagListController.NotificationType.Name.tagPersistentStoreRequiresReloadNotification,
                object: nil
            )
        } catch {
            presentError(error)
        }
    }
    
    @IBAction func resetTagDatabaseAction(_ sender: NSButton) {
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
    
    @IBAction func actionRequiresRestart(_ sender: NSButton) {
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
        return "AdvancedPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Advanced", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Advanced")
    }
    
}
