//
//  NSColorPanel+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 7/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ObjectiveC

private let fooAssociation = AssociatedObject<Any>()

extension NSColorPanel {
    var strongTarget: Any? {
        get { fooAssociation[self] }
        set {
            setTarget(newValue)
            fooAssociation[self] = newValue
        }
    }
}

