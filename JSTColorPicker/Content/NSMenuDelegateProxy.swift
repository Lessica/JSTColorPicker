//
//  NSMenuDelegateProxy.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@objc
protocol NSMenuDelegateAlternate {
    @objc optional func menuNeedsUpdateAlternate(_ altMenu: NSMenu)
}

class NSMenuDelegateProxy: NSObject {
    @IBOutlet public weak var delegate: NSMenuDelegateAlternate?
}

extension NSMenuDelegateProxy: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        delegate?.menuNeedsUpdateAlternate?(menu)
    }
}

