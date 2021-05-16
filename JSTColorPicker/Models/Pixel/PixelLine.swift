//
//  PixelLine.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/5/16.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import LuaSwift

struct PixelLine: Codable {
    
    public var coordinate1: PixelCoordinate { PixelCoordinate(x: x1, y: y1) }
    public var coordinate2: PixelCoordinate { PixelCoordinate(x: x2, y: y2) }
    
    public let x1: Int
    public let y1: Int
    public let x2: Int
    public let y2: Int
    
    init(x1: Int, y1: Int, x2: Int, y2: Int) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
    
    init(coordinate1: PixelCoordinate, coordinate2: PixelCoordinate) {
        self.x1 = coordinate1.x
        self.y1 = coordinate1.y
        self.x2 = coordinate2.x
        self.y2 = coordinate2.y
    }
    
}

extension PixelLine: CustomStringConvertible {
    
    var description: String {
        return "line{x1:\(x1),y1:\(y1),x2:\(x2),y2:\(y2)}"
    }
    
}

extension PixelLine: Hashable {
    
    static func == (lhs: PixelLine, rhs: PixelLine) -> Bool {
        return (lhs.coordinate1 == rhs.coordinate1 && lhs.coordinate2 == rhs.coordinate2) || (lhs.coordinate1 == rhs.coordinate2 && lhs.coordinate2 == rhs.coordinate1)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(x1)
        hasher.combine(y1)
        hasher.combine(x2)
        hasher.combine(y2)
    }
    
}

extension PixelLine: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["x1"] = x1
        t["y1"] = y1
        t["x2"] = x2
        t["y2"] = y2
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["x1", "y1", "x2", "y2"]
    private static let typeName: String = "\(String(describing: PixelLine.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    static func arg(_ vm: VirtualMachine, value: Value) -> String? {
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
