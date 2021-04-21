import CoreGraphics

extension CGPoint: Value {
    
    public func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["x"] = Double(self.x)
        t["y"] = Double(self.y)
        t.push(vm)
    }
    
    public func kind() -> Kind { return .table }
    
    private static let typeName: String = "CGPoint (Table Keys [x,y])"
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["x"] is Number) || !(t["y"] is Number) { return typeName }
        return nil
    }
    
}

extension CGSize: Value {
    
    public func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["width"] = Double(self.width)
        t["height"] = Double(self.height)
        t.push(vm)
    }
    
    public func kind() -> Kind { return .table }
    
    private static let typeName: String = "CGSize (Table Keys [width,height])"
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["width"] is Number) || !(t["height"] is Number) { return typeName }
        return nil
    }
    
}

extension Data: Value {
    
    public func push(_ vm: VirtualMachine) {
        withUnsafeBytes { (pointer) -> Void in
            if let pointer = pointer.bindMemory(to: Int8.self).baseAddress {
                lua_pushlstring(vm.vm, pointer, count)
            }
        }
    }
    
    public func kind() -> Kind { .string }
    
    public static func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .string { return "string" }
        return nil
    }
    
}

extension Table {
    
    public func toPoint() -> CGPoint? {
        let x = self["x"] as? Number
        let y = self["y"] as? Number
        if x == nil || y == nil { return nil }
        return CGPoint(x: x!.toDouble(), y: y!.toDouble())
    }
    
    public func toSize() -> CGSize? {
        let w = self["width"] as? Number
        let h = self["height"] as? Number
        if w == nil || h == nil { return nil }
        return CGSize(width: w!.toDouble(), height: h!.toDouble())
    }
    
}

extension Arguments {
    
    public var point: CGPoint { return (values.remove(at: 0) as! Table).toPoint()! }
    public var size:  CGSize  { return (values.remove(at: 0) as! Table).toSize()!  }
    
}
