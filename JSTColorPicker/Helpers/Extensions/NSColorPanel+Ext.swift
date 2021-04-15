//
//  NSColorPanel+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 7/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ObjectiveC

extension NSColorPanel {
    
    private struct AssociatedKey {
        static var strongTarget = "strongTarget"
    }
    
    var strongTarget: Any? {
        get {
            return getAssociatedObject(object: self, associativeKey: &AssociatedKey.strongTarget)
        }
        set {
            setTarget(newValue)
            setAssociatedObject(object: self, value: newValue, associativeKey: &AssociatedKey.strongTarget, policy: objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
}

