//
//  AppDelegate+ColorPanel.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Color Panel Actions
    
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.touchBar = nil
        return panel
    }
    
    @IBAction private func colorPanelSwitchMenuItemTapped(_ sender: NSMenuItem) {
        if !colorPanel.isVisible {
            colorPanel.makeKeyAndOrderFront(sender)
        } else {
            colorPanel.close()
        }
    }
    
}

