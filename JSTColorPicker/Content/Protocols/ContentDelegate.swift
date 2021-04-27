//
//  ContentDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol ContentDelegate: AnyObject {
    func addContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem?
    func addContentItem(of rect: PixelRect, byIgnoringPopups ignore: Bool) throws -> ContentItem?
    
    func updateContentItem(_ item: ContentItem, to coordinate: PixelCoordinate) throws -> ContentItem?
    func updateContentItem(_ item: ContentItem, to rect: PixelRect) throws -> ContentItem?
    func updateContentItem(_ item: ContentItem) throws -> ContentItem?
    func updateContentItems(_ items: [ContentItem]) throws -> [ContentItem]?
    
    func selectContentItem(_ item: ContentItem, byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> ContentItem?
    func selectContentItems(_ items: [ContentItem], byExtendingSelection extend: Bool, byFocusingSelection focus: Bool) throws -> [ContentItem]?
    func deselectContentItem(_ item: ContentItem) throws -> ContentItem?
    func deselectAllContentItems()
    
    func deleteContentItem(of coordinate: PixelCoordinate, byIgnoringPopups ignore: Bool) throws -> ContentItem?
    func deleteContentItem(_ item: ContentItem, byIgnoringPopups ignore: Bool) throws -> ContentItem?

    func copyContentItem(of coordinate: PixelCoordinate) throws -> ContentItem?
}

