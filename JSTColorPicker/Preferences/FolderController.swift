//
//  FolderController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/28/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class FolderController: NSViewController {
    
    init() {
        super.init(nibName: "Folder", bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction func actionRequiresRestart(_ sender: NSButton) {
        
    }
    
}

extension FolderController: MASPreferencesViewController {
    
    var hasResizableWidth: Bool {
        return false
    }
    
    var hasResizableHeight: Bool {
        return false
    }
    
    var viewIdentifier: String {
        return "FolderPreferences"
    }
    
    var toolbarItemLabel: String? {
        return NSLocalizedString("Folder", comment: "toolbarItemLabel")
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")
    }
    
}
