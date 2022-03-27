//
//  PreferencesController.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/2/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import MASPreferences

final class PreferencesController: MASPreferencesWindowController {
    
    static let registerInitialValuesNotification = Notification.Name("PreferencesController.registerInitialValuesNotification")
    static let makeKeyAndOrderFrontNotification = Notification.Name("PreferencesController.makeKeyAndOrderFrontNotification")
    
    static let initialValuesURL = try! FileManager.default.url(
        for: .libraryDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
    ).appendingPathComponent("InitialValues", isDirectory: false)
    
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.level = .floating
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        window?.standardWindowButton(.zoomButton)?.isHidden = true
        window?.standardWindowButton(.zoomButton)?.isEnabled = false
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(makeKeyAndOrderFrontNotificationReceived(_:)),
            name: PreferencesController.makeKeyAndOrderFrontNotification,
            object: nil
        )
    }
    
    @objc func makeKeyAndOrderFrontNotificationReceived(_ notification: NSNotification) {
        if let viewIdentifier = notification.userInfo?["viewIdentifier"] as? String {
            select(withIdentifier: viewIdentifier)
        }
    }
    
}
