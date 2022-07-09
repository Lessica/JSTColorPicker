//
//  PixelColor.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/21/20.
//  Copyright © 2020 JST. All rights reserved.
//

extension PixelColor {
    public func copyEquivalentColor(inImage image: PixelImage, ofColorSpace colorSpace: NSColorSpace) -> PixelColor {
        let item = PixelColor(
            id: id,
            coordinate: coordinate,
            color: JSTPixelColor(systemColor: toNSColor(from: image.colorSpace, to: colorSpace))
        )
        item.tags = tags
        item.similarity = similarity
        item.userInfo = userInfo
        return item
    }
}

