//
//  TagListDragDelegate.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/27.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListDragDelegate: class {
    
    var canPerformDrag: Bool { get }
    var selectedRowIndexes: IndexSet { get }
    func selectedRowIndexes(at point: CGPoint, shouldHighlight: Bool) -> IndexSet
    
}
