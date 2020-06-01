//
//  TagListDataSource.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/27.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension NSNotification.Name {
    public static let NSManagedObjectContextDidLoad = NSNotification.Name("NSManagingContextDidLoadNotification")
}

protocol TagListDataSource: class {
    
    var managedObjectContext: NSManagedObjectContext { get }
    
    var managedTags: [Tag] { get }
    func managedTag(of name: String) -> Tag?
    func managedTags(of names: [String]) -> [Tag]
    
    var managedTagController: TagController { get }
    
}
