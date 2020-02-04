//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class PixelColor: ContentItem {
    
    var coordinate: PixelCoordinate
    var pixelColorRep: JSTPixelColor
    
    init(id: Int, coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate    = coordinate
        self.pixelColorRep = color
        super.init(id: id)
    }
    
    required init?(coder: NSCoder) {
        guard let pixelColorRep = coder.decodeObject(forKey: "pixelColorRep") as? JSTPixelColor else { return nil }
        let coordX = coder.decodeInteger(forKey: "coordinate.x")
        let coordY = coder.decodeInteger(forKey: "coordinate.y")
        self.coordinate    = PixelCoordinate(x: coordX, y: coordY)
        self.pixelColorRep = pixelColorRep
        super.init(coder: coder)
    }
    
    deinit {
        debugPrint("- [PixelColor deinit]")
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(coordinate.x, forKey: "coordinate.x")
        coder.encode(coordinate.y, forKey: "coordinate.y")
        coder.encode(pixelColorRep, forKey: "pixelColorRep")
    }
}

extension PixelColor /*: Equatable*/ {
    static func == (lhs: PixelColor, rhs: PixelColor) -> Bool {
        return lhs.coordinate == rhs.coordinate
    }
}

extension PixelColor /*: CustomStringConvertible*/ {
    override var description: String {
        return "\(pixelColorRep) \(coordinate)"
    }
}
