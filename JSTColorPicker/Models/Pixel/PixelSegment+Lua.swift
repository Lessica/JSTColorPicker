//
//  PixelSegment+Lua.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/5/16.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension PixelSegment: LuaSwift.Value {
    
    public func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["x1"] = x1
        t["y1"] = y1
        t["x2"] = x2
        t["y2"] = y2
        t.push(vm)
    }
    
    public func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["x1", "y1", "x2", "y2"]
    private static let typeName: String = "\(String(describing: PixelSegment.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["x1"] is Number) ||
                !(t["y1"] is Number) ||
                !(t["x2"] is Number) ||
                !(t["y2"] is Number)
        {
            return typeName
        }
        return nil
    }
    
}
