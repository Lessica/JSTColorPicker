//
//  TagListSource.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/27.
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
}
