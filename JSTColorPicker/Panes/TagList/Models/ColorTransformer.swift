//
//  ColorTransformer.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/25.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@objc(ColorTransformer)
final class ColorTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSColor.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let type = value as? String else { return nil }
        return NSColor(hex: type)
    }
}
