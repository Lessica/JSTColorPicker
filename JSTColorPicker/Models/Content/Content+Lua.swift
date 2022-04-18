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
        t["colors"] = vm.createTable(withSequence: lazyColors)
        t["areas"] = vm.createTable(withSequence: lazyAreas)
        t["get_data"] = vm.createFunction([], { (_) -> SwiftReturnValue in
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true) {
                return .value(data)
            }
            return .error(Screenshot.Error.invalidContent.failureReason!)
        })
        t.push(vm)
    }

    func kind() -> Kind { return .table }

    private static let typeKeys: [String] = ["colors", "areas", "get_data"]
    private static let typeName: String = "\(String(describing: Content.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["colors"] is Table) ||
            !(t["areas"] is Table) ||
            !(t["get_data"] is Function)
        {
            return typeName
        }
        return nil
    }
}
