//
//  ObjC+Ext.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

final class Lifted<T> {
    let value: T
    init(_ x: T) {
        value = x
    }
}

func lift<T>(x: T) -> Lifted<T>  {
    return Lifted(x)
}

func setAssociatedObject<T>(object: AnyObject, value: T, associativeKey: UnsafeRawPointer, policy: objc_AssociationPolicy) {
    if let v: AnyObject = value as? AnyObject {
        objc_setAssociatedObject(object, associativeKey, v,  policy)
    } else {
        objc_setAssociatedObject(object, associativeKey, lift(x: value),  policy)
    }
}

func getAssociatedObject<T>(object: AnyObject, associativeKey: UnsafeRawPointer) -> T? {
    if let v = objc_getAssociatedObject(object, associativeKey) as? T {
        return v
    } else if let v = objc_getAssociatedObject(object, associativeKey) as? Lifted<T> {
        return v.value
    } else {
        return nil
    }
}
