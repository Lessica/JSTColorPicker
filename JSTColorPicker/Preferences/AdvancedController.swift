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
    
    init() {
        super.init(nibName: "Advanced", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func resetAllAction(_ sender: NSButton) {
        NSUserDefaultsController.shared.revertToInitialValues(sender)
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
        return "Advanced"
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(named: NSImage.advancedName)
    }
    
}
