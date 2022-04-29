//
//  AppDelegate+Subscribe.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Subscribe Actions
    
    @IBAction internal func subscribeMenuItemTapped(_ sender: NSMenuItem) {
        PurchaseWindowController.shared.showWindow(sender)
    }
    
}

