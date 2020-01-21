//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

struct PixelCoordinate {
    var x: Int
    var y: Int
    init(_ point: CGPoint) {
        x = Int(point.x)
        y = Int(point.y)
    }
}

class PixelColor {
    
    var coordinate: PixelCoordinate
    var pixelColorRep: JSTPixelColor
    
    init(coordinate: PixelCoordinate, color: JSTPixelColor) {
        self.coordinate = coordinate
        self.pixelColorRep = color
    }
    
}
