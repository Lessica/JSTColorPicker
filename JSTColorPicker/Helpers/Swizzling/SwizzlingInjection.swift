//
//  SwizzlingInjection.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/2.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

protocol SwizzlingInjection: class {
    static func inject()
}

extension NSApplication {
    open override var nextResponder: NSResponder? {
        get {
            // Called before applicationDidFinishLaunching
            SwizzlingHelper.enableInjection()
            return super.nextResponder
        }
        set {
            super.nextResponder = newValue
        }
    }
}
