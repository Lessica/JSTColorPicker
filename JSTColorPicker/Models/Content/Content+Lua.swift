//
//  Content+Lua.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension Content: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable(withSequence: items)
        t.push(vm)
    }
    
    func kind() -> Kind {
        return .table
    }
    
    private static let typeName: String = "Content (Table Array)"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        return nil
    }
    
}
