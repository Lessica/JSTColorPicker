//
//  ContentItemSource.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol ContentItemSource: AnyObject {
    func contentItem(of coordinate: PixelCoordinate) throws -> ContentItem
    func contentItem(of rect: PixelRect) throws -> ContentItem
}
