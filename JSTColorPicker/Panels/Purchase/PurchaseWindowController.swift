//
//  PurchaseWindowController.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class PurchaseWindowController: NSWindowController {
    
    static let shared = newController()
    
    private static func newController() -> PurchaseWindowController {
        let windowStoryboard = NSStoryboard(name: "Purchase", bundle: nil)
        let windowController = windowStoryboard.instantiateInitialController() as! PurchaseWindowController
        return windowController
    }
    
    var isVisible: Bool { window?.isVisible ?? false }
    
}
