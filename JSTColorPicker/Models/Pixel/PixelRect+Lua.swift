//
//  PixelRect+Lua.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension PixelRect: LuaSwift.Value {
    
    public func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["minX"] = minX
        t["minY"] = minY
        t["maxX"] = maxX
        t["maxY"] = maxY
        t["width"] = width
        t["height"] = height
        t.push(vm)
    }
    
    public func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["minX", "minY", "maxX", "maxY", "width", "height"]
    private static let typeName: String = "\(String(describing: PixelRect.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["minX"]   is Number)  ||
                !(t["minY"]   is Number)  ||
                !(t["maxX"]   is Number)  ||
                !(t["maxY"]   is Number)  ||
                !(t["width"]  is Number)  ||
                !(t["height"] is Number)
        { return typeName }
        return nil
    }
    
}
