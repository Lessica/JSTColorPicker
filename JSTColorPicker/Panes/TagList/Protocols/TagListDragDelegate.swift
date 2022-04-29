//
//  TagListDragDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/5/27.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListDragDelegate: AnyObject {
    
    func shouldPerformDragging(_ sender: NSView, with event: NSEvent) -> Bool
    func willPerformDragging(_ sender: NSView) -> Bool
    
    var selectedRowIndexes: IndexSet { get }
    func selectRow(
        at point: CGPoint,
        byExtendingSelection extend: Bool,
        byFocusingSelection focus: Bool
    ) -> IndexSet
    
    func visibleRects(of rowIndexes: IndexSet) -> [CGRect]
    
}
