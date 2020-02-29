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
        return "Folder"
    }
    
    var toolbarItemImage: NSImage? {
        return NSImage(named: NSImage.folderName)
    }
    
}