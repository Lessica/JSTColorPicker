//
//  ColorGridWindow.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ColorGridWindow: NSPanel {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        isFloatingPanel = true
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = true
    }
    
}
