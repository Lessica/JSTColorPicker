//
//  PixelSize.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

struct PixelSize: Codable {
    public static var zero: PixelSize {
        return PixelSize()
    }
    public var width:  Int = 0
    public var height: Int = 0
    init() {}
    init(width: Int, height: Int) {
        self.width  = width
        self.height = height
    }
    init(_ size: CGSize) {
        width  = Int(floor(size.width))
        height = Int(floor(size.height))
    }
    public func toCGSize() -> CGSize {
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
}

extension PixelSize: CustomStringConvertible {
    var description: String {
        return "{w:\(width),h:\(height)}"
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

extension PixelSize: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["w"] = width
        t["h"] = height
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "pixel size (table with keys [w,h])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["w"] is Number) || !(t["h"] is Number) { return typeName }
        return nil
    }
    
}
