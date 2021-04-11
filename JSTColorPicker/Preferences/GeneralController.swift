//
//  GeneralController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class GeneralController: NSViewController {
    
    @IBOutlet weak var tabView: NSTabView!
    @objc dynamic var maximumCount: Int = 9999
    @objc dynamic var minimumCount: Int = 1
    
    init() {
        super.init(nibName: "General", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func actionRequiresRestart(_ sender: NSButton) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Restart required", comment: "actionRequiresRestart(_:)")
        alert.informativeText = NSLocalizedString("This option requires application to restart to complete the modification.", comment: "actionRequiresRestart(_:)")
        alert.addButton(withTitle: NSLocalizedString("Restart", comment: "actionRequiresRestart(_:)"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "actionRequiresRestart(_:)"))
        alert.beginSheetModal(for: view.window!) { resp in
            if resp == .alertFirstButtonReturn {
                NSApp.relaunch(sender)
            }
        }
    }
    
}

extension GeneralController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return true
    }
    
    var viewIdentifier: String {
        return "GeneralPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("General", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "General")
    }
    
}
