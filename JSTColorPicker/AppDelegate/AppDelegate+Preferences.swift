//
//  AppDelegate+Preferences.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension AppDelegate {
    
    // MARK: - Preferences Observation
    
    internal func prepareDefaults() {
        isNetworkDiscoveryEnabled = UserDefaults.standard[.enableNetworkDiscovery]
    }
    
    internal func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .enableNetworkDiscovery, let toValue = defaultValue as? Bool {
            if isNetworkDiscoveryEnabled != toValue {
                isNetworkDiscoveryEnabled = toValue
                
                applicationBonjourSetup(deactivate: true)
            }
        }
    }
    
    
    // MARK: - Preferences Actions
    
    @objc func showPreferences(_ sender: Any?) {
        if let prefsWindow = preferencesController.window,
           !prefsWindow.isVisible,
           let keyScreen = tabService?.firstRespondingWindow?.screen,
           let prefsScreen = prefsWindow.screen,
           keyScreen != prefsScreen
        {
            prefsWindow.setFrameOrigin(CGPoint(
                x: keyScreen.frame.minX + ((prefsWindow.frame.minX - prefsScreen.frame.minX) / prefsScreen.frame.width * keyScreen.frame.width),
                y: keyScreen.frame.minY + ((prefsWindow.frame.minY - prefsScreen.frame.minY) / prefsScreen.frame.height * keyScreen.frame.height)
            ))
        }
        preferencesController.showWindow(sender)
    }
    
    @IBAction private func showPreferencesItemTapped(_ sender: NSMenuItem) {
        showPreferences(sender)
    }
    
}


// MARK: - Debug Preferences

#if DEBUG
extension AppDelegate {
    @objc internal func applicationApplyPreferences(_ notification: Notification?) { }
}
#endif

