//
//  ContentDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol ContentDelegate: class {
    
    func addContentItem(of coordinate: PixelCoordinate) throws -> ContentItem?
    func addContentItem(of rect: PixelRect) throws -> ContentItem?
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem?
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem?
    func updateContentItem(_ item: ContentItem) throws -> ContentItem?
    func updateContentItems(_ items: [ContentItem]) throws -> [ContentItem]?
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool) throws -> ContentItem?
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool) throws -> [ContentItem]?
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem?
    func deselectAllContentItems()
    
    func deleteContentItem(of coordinate: PixelCoordinate) throws -> ContentItem?
    func deleteContentItem(_ item: ContentItem) throws -> ContentItem?
    
}

