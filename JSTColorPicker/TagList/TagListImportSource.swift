//
//  TagListImportSource.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/21.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TagListImportSource: class {
    
    var importableTagNames: [String]? { get }
    
}
