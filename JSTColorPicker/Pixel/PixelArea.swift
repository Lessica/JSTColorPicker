//
//  PixelArea.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/3/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class PixelArea: ContentItem {
    
    var rect: PixelRect
    
    init(id: Int, rect: PixelRect) {
        self.rect = rect
        super.init(id: id)
    }
    
    required init?(coder: NSCoder) {
        let coordX = coder.decodeInteger(forKey: "rect.origin.x")
        let coordY = coder.decodeInteger(forKey: "rect.origin.y")
        let sizeW = coder.decodeInteger(forKey: "rect.size.width")
        let sizeH = coder.decodeInteger(forKey: "rect.size.height")
        self.rect = PixelRect(x: coordX, y: coordY, width: sizeW, height: sizeH)
        super.init(coder: coder)
    }
    
    deinit {
        debugPrint("- [PixelArea deinit]")
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(rect.origin.x, forKey: "rect.origin.x")
        coder.encode(rect.origin.y, forKey: "rect.origin.y")
        coder.encode(rect.size.width, forKey: "rect.size.width")
        coder.encode(rect.size.height, forKey: "rect.size.height")
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
