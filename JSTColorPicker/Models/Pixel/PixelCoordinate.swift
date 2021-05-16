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
    
    public static var zero: PixelCoordinate { PixelCoordinate(x: 0, y: 0) }
    
    public static var null: PixelCoordinate { PixelCoordinate(x: Int.max, y: Int.max) }
    
    public var isNull: Bool { self == PixelCoordinate.null }
    
    public let x: Int
    public let y: Int
    
    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    init(_ point: CGPoint) {
        x = Int(point.x)
        y = Int(point.y)
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
    
    private static let typeKeys: [String] = ["x", "y"]
    private static let typeName: String = "\(String(describing: PixelCoordinate.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["x"] is Number) || !(t["y"] is Number) { return typeName }
        return nil
    }
    
}
