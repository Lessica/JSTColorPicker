//
//  PurchaseWindow.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class PurchaseWindow: NSPanel {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        isRestorable = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isMovable = true
        isMovableByWindowBackground = true
    }
    
    override func cancelOperation(_ sender: Any?) {
        super.cancelOperation(sender)
        PurchaseManager.shared.tryDemoVersion()
        close()
    }
    
}
