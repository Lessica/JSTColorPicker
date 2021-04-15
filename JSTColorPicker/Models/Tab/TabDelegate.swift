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
    var window: NSWindow { windowController.window! }
    
    /// React to window closing, auto-unsubscribing on dealloc
    let closingSubscription: NotificationToken
    
    init(windowActiveOrder: Int, windowController: WindowController, closingSubscription: NotificationToken) {
        self.windowActiveOrder = windowActiveOrder
        self.windowController = windowController
        self.closingSubscription = closingSubscription
    }
}

protocol TabDelegate: class {
    func addManagedWindow(windowController: WindowController) -> ManagedWindow?
    
    @discardableResult
    func activeManagedWindow(windowController: WindowController) -> Int?
}
