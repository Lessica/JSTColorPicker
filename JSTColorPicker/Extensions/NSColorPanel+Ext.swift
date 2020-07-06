//
//  NSColorPanel+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 7/6/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import ObjectiveC

final class Lifted<T> {
    let value: T
    init(_ x: T) {
        value = x
    }
}

private func lift<T>(x: T) -> Lifted<T>  {
    return Lifted(x)
}

private func setAssociatedObject<T>(object: AnyObject, value: T, associativeKey: UnsafeRawPointer, policy: objc_AssociationPolicy) {
    if let v: AnyObject = value as? AnyObject {
        objc_setAssociatedObject(object, associativeKey, v,  policy)
    } else {
        objc_setAssociatedObject(object, associativeKey, lift(x: value),  policy)
    }
}

private func getAssociatedObject<T>(object: AnyObject, associativeKey: UnsafeRawPointer) -> T? {
    if let v = objc_getAssociatedObject(object, associativeKey) as? T {
        return v
    } else if let v = objc_getAssociatedObject(object, associativeKey) as? Lifted<T> {
        return v.value
    } else {
        return nil
    }
}

extension NSColorPanel {
    
    private struct AssociatedKey {
        static var strongTarget = "strongTarget"
    }
    
    public var strongTarget: Any? {
        get {
            return getAssociatedObject(object: self, associativeKey: &AssociatedKey.strongTarget)
        }
        set {
            setTarget(newValue)
            setAssociatedObject(object: self, value: newValue, associativeKey: &AssociatedKey.strongTarget, policy: objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
}

