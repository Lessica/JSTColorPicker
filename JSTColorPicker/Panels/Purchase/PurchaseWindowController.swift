//
//  PurchaseWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class PurchaseWindowController: NSWindowController {
    
    static var sharedLoaded = false
    static let shared: PurchaseWindowController = {
        sharedLoaded = true
        return newController()
    }()
    
    private static func newController() -> PurchaseWindowController {
        let windowStoryboard = NSStoryboard(name: "Purchase", bundle: nil)
        let windowController = windowStoryboard.instantiateInitialController() as! PurchaseWindowController
        return windowController
    }
    
    var isVisible: Bool { window?.isVisible ?? false }
    
}
