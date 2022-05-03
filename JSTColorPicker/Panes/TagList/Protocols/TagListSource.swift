//
//  TagListSource.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/5/27.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSNotification.Name {
    static let NSManagedObjectContextDidLoad = NSNotification.Name("NSManagingContextDidLoadNotification")
}

protocol TagListSource: AnyObject {
    
    var managedObjectContext: NSManagedObjectContext? { get }
    func managedTag(of name: String) -> Tag?
    func managedTags(of names: [String]) -> [Tag]
    
    var arrangedTags: [Tag] { get }
    var arrangedTagController: TagController { get }
    
    var shouldAssignSelectedTags: Bool { get }
    var selectedTags: [Tag] { get }
    var selectedTagNames: [String] { get }
    
    func setSelectedTags(_ tags: [Tag]) -> Bool
    func setSelectedTagNames(_ tagNames: [String]) -> Bool

    func addSelectedTags(_ tags: [Tag]) -> Bool
    func addSelectedTagNames(_ tagNames: [String]) -> Bool
    
    func removeSelectedTags(_ tags: [Tag]) -> Bool
    func removeSelectedTagNames(_ tagNames: [String]) -> Bool
    
    func removeAllSelectedTags() -> Bool
}
