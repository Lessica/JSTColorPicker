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
    
    @IBAction func resetAllAction(_ sender: NSButton) {
        NSUserDefaultsController.shared.revertToInitialValues(sender)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        #if SANDBOXED
        checkUpdatesCheckbox.isEnabled = false
        #else
        checkUpdatesCheckbox.isEnabled = true
        #endif
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        UserDefaults.standard[.checkUpdatesAutomatically] = (NSApp.delegate as? AppDelegate)?.sparkUpdater.automaticallyChecksForUpdates ?? false
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
        return NSImage(named: NSImage.advancedName)
    }
    
}
