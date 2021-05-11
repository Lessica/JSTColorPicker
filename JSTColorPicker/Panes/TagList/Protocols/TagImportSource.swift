//
//  TagImportSource.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/21.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TagImportSource: AnyObject {
    var importableTagNames: [String]? { get }
}
