//
//  ManagedTabWindow.swift
//  JSTColorPicker
//
//  Created by Rachel on 5/13/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class ManagedTabWindow: ManagedWindow {
    /// Record the history access order
    var windowActiveOrder: Int
    
    /// Keep the controller around to store a strong reference to it
    let windowController: WindowController
    
    init(windowActiveOrder: Int, windowController: WindowController, closingSubscription: NotificationToken) {
        self.windowActiveOrder = windowActiveOrder
        self.windowController = windowController
        super.init(window: windowController.window!, closingSubscription: closingSubscription)
    }
}
