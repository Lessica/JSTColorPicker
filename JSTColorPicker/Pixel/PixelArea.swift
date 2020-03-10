//
//  PixelArea.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

class PixelArea: ContentItem {
    override class var supportsSecureCoding: Bool {
        return true
    }
    
    public fileprivate(set) var rect: PixelRect
    
    init(id: Int, rect: PixelRect) {
        self.rect = rect
        super.init(id: id)
    }
    
    init(rect: PixelRect) {
        self.rect = rect
        super.init(id: 0)
    }
    
    enum CodingKeys: String, CodingKey {
        case rect
    }
    
    required init?(coder: NSCoder) {
        let coordX = coder.decodeInteger(forKey: "rect.origin.x")
        let coordY = coder.decodeInteger(forKey: "rect.origin.y")
        let sizeW  = coder.decodeInteger(forKey: "rect.size.width")
        let sizeH  = coder.decodeInteger(forKey: "rect.size.height")
        self.rect  = PixelRect(x: coordX, y: coordY, width: sizeW, height: sizeH)
        super.init(coder: coder)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rect = try container.decode(PixelRect.self, forKey: .rect)
        try super.init(from: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    deinit {
        // debugPrint("- [PixelArea deinit]")
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PixelArea else { return false }
        return self == object
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rect, forKey: .rect)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(rect.origin.x, forKey: "rect.origin.x")
        coder.encode(rect.origin.y, forKey: "rect.origin.y")
        coder.encode(rect.size.width, forKey: "rect.size.width")
        coder.encode(rect.size.height, forKey: "rect.size.height")
    }
    
    override func copy(with zone: NSZone? = nil) -> Any {
        return PixelArea(id: id, rect: rect)
    }
    
    override func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["id"] = id
        t["similarity"] = similarity
        t["x"] = rect.x
        t["y"] = rect.y
        t["w"] = rect.width
        t["h"] = rect.height
        t.push(vm)
    }
    
    override func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "pixel area (table with keys [id,similarity,x,y,w,h])"
    override class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["id"] is Number) || !(t["similarity"] is Number) || !(t["x"] is Number) ||
            !(t["y"] is Number) || !(t["w"] is Number) || !(t["h"] is Number)
        {
            return typeName
        }
        return nil
    }
    
}

extension PixelArea /*: Equatable*/ {
    static func == (lhs: PixelArea, rhs: PixelArea) -> Bool {
        return lhs.rect == rhs.rect
    }
}

extension PixelArea /*: CustomStringConvertible*/ {
    override var description: String {
        return rect.description
    }
}
