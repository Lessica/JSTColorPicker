//
//  PixelSize.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

public struct PixelSize: Codable {
    
    static var zero: PixelSize { PixelSize(width: 0, height: 0) }
    
    var isValid: Bool { width >= 0 && height >= 0 }
    
    let width:  Int
    let height: Int
    
    init(width: Int, height: Int) {
        self.width  = width
        self.height = height
    }
    
    init(_ size: CGSize) {
        width  = Int(size.width)
        height = Int(size.height)
    }
    
    func toCGSize() -> CGSize {
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }
    
}

extension PixelSize: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return "{w:\(width),h:\(height)}"
    }
    
    public var debugDescription: String {
        return "size{w:\(width),h:\(height)}"
    }
    
}

extension PixelSize: Hashable {
    
    public static func == (lhs: PixelSize, rhs: PixelSize) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
    
}

extension PixelSize: Comparable {
    
    public static func < (lhs: PixelSize, rhs: PixelSize) -> Bool {
        return lhs.width * lhs.height < rhs.width * rhs.height
    }
    
}

extension PixelSize: LuaSwift.Value {
    
    public func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["width"] = width
        t["height"] = height
        t.push(vm)
    }
    
    public func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = ["width", "height"]
    private static let typeName: String = "\(String(describing: PixelSize.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
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
