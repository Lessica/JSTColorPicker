//
//  TagListDragDelegate.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/5/27.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListDragDelegate: AnyObject {
    
    var shouldPerformDragging: Bool { get }
    func willPerformDragging(_ sender: Any?) -> Bool
    var selectedRowIndexes: IndexSet { get }
    
    func selectedRowIndexes(at point: CGPoint, shouldHighlight: Bool) -> IndexSet
    func visibleRects(of rowIndexes: IndexSet) -> [CGRect]
    
}
