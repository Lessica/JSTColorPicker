//
//  TabDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

struct ManagedWindow {
    /// Keep the controller around to store a strong reference to it
    let windowController: NSWindowController
    
    /// Keep the window around to identify instances of this type
    let window: NSWindow
    
    /// React to window closing, auto-unsubscribing on dealloc
    let closingSubscription: NotificationToken
}

protocol TabDelegate: class {
    func addManagedWindow(windowController: WindowController) -> ManagedWindow?
}
