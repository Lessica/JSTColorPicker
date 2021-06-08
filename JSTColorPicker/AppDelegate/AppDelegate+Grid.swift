//
//  AppDelegate+Grid.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Color Grid Actions
    
    private var isGridVisible: Bool { GridWindowController.shared.isVisible }
    
    internal func toggleGridVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            GridWindowController.shared.showWindow(sender)
        } else {
            GridWindowController.shared.close()
        }
        NSApp.invalidateRestorableState()
    }
    
    @objc private func gridSwitch(_ sender: Any?) {
        if isGridVisible {
            toggleGridVisibleState(false, sender: sender)
        } else {
            toggleGridVisibleState(true, sender: sender)
        }
    }
    
    @IBAction private func gridSwitchMenuItemTapped(_ sender: NSMenuItem) {
        gridSwitch(sender)
    }
    
}

