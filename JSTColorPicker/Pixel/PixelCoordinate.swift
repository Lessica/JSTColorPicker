//
//  PixelCoordinate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

struct PixelCoordinate: Codable {
    
    public static var zero: PixelCoordinate { PixelCoordinate() }
    
    public static var null: PixelCoordinate { PixelCoordinate(x: Int.max, y: Int.max) }
    
    public var isNull: Bool { self == PixelCoordinate.null }
    
    public var x: Int = 0
    public var y: Int = 0
    
    init() {}
    
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        x = Int(floor(point.x))
        y = Int(floor(point.y))
    }
    
    func toCGPoint() -> CGPoint {
        if isNull {
            return .null
        }
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
}

extension PixelCoordinate: CustomStringConvertible {
    
    var description: String {
        return "(\(x),\(y))"
    }
    
}

extension PixelCoordinate: Hashable {
    
    static func == (lhs: PixelCoordinate, rhs: PixelCoordinate) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
}

extension PixelCoordinate: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["x"] = x
        t["y"] = y
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeName: String = "pixel coordinate (table with keys [x,y])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["x"] is Number) || !(t["y"] is Number) { return typeName }
        return nil
    }
    
}
