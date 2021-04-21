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
    
    public static var zero: PixelSize { PixelSize() }
    
    public var width:  Int = 0
    public var height: Int = 0
    
    init() {}
    
    init(width: Int, height: Int) {
        self.width  = width
        self.height = height
    }
    
    init(_ size: CGSize) {
        width  = Int(size.width)
        height = Int(size.height)
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

extension PixelSize: Hashable {
    
    static func == (lhs: PixelSize, rhs: PixelSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
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
        t["width"] = width
        t["height"] = height
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["width", "height"]
    private static let typeName: String = "PixelSize (Table Keys [\(typeKeys.joined(separator: ","))])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["width"] is Number) ||
            !(t["height"] is Number)
        {
            return typeName
        }
        return nil
    }
    
}
