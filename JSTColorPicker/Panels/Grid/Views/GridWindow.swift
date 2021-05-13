//
//  GridWindow.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/20/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class GridWindow: NSPanel {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        isRestorable = false
        isFloatingPanel = true
        hidesOnDeactivate = true
        becomesKeyOnlyIfNeeded = true
        isMovable = true
        isMovableByWindowBackground = true
    }
    
}
