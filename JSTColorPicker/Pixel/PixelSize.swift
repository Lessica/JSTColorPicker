//
//  PixelSize.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelSize {
    public static var zero: PixelSize {
        return PixelSize()
    }
    public static var invalid: PixelSize {
        return PixelSize(width: NSNotFound, height: NSNotFound)
    }
    var width: Int = 0
    var height: Int = 0
    init() {}
    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    init(_ size: CGSize) {
        width = Int(floor(size.width))
        height = Int(floor(size.height))
    }
    func toCGSize() -> CGSize {
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}

extension PixelSize: CustomStringConvertible {
    var description: String {
        return "(\(width),\(height))"
    }
}

extension PixelSize: Equatable {
    static func == (lhs: PixelSize, rhs: PixelSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
}

extension PixelSize: Comparable {
    static func < (lhs: PixelSize, rhs: PixelSize) -> Bool {
        return lhs.width * lhs.height < rhs.width * rhs.height
    }
}
