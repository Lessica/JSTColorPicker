//
//  AppDelegate+Help.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Help Actions
    
    @IBAction private func showHelpPageMenuItemTapped(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToLocalHelpPage()
    }
    
    @IBAction private func actionRedirectToTermsAndPrivacyPage(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToTermsPage()
    }
    
    @IBAction private func actionRedirectToMainPage(_ sender: NSMenuItem) {
        NSWorkspace.shared.redirectToMainPage()
    }
    
}

