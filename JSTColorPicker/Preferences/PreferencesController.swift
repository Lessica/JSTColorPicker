//
//  PreferencesController.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/2/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

class PreferencesController: MASPreferencesWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.level = .floating
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isEnabled = false
    }
    
}
