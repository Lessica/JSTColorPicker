//
//  ContentResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol ContentResponder: class {
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem?
    func addContentItem(of rect: PixelRect) throws -> ContentItem?
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem?
}
