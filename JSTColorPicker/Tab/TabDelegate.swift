//
//  TabDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ManagedWindow {
    /// Record the history access order
    var windowActiveOrder: Int
    
    /// Keep the controller around to store a strong reference to it
    let windowController: WindowController
    
    /// Keep the window around to identify instances of this type
    let window: NSWindow
    
    /// React to window closing, auto-unsubscribing on dealloc
    let closingSubscription: NotificationToken
    
    init(windowActiveOrder: Int, windowController: WindowController, window: NSWindow, closingSubscription: NotificationToken) {
        self.windowActiveOrder = windowActiveOrder
        self.windowController = windowController
        self.window = window
        self.closingSubscription = closingSubscription
    }
}

protocol TabDelegate: class {
    func addManagedWindow(windowController: WindowController) -> ManagedWindow?
    
    @discardableResult
    func activeManagedWindow(windowController: WindowController) -> Int?
}
