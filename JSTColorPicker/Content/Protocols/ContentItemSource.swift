//
//  ContentItemSource.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol ContentItemSource: AnyObject {
    func contentItem(of coordinate: PixelCoordinate) throws -> ContentItem
    func contentItem(of rect: PixelRect) throws -> ContentItem
    func contentItem(at rowIndex: Int) -> ContentItem?
    func contentItems(at rowIndexes: IndexSet) -> [ContentItem]
}
