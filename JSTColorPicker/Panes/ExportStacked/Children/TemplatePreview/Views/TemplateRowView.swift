//
//  TemplateRowView.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/29/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class TemplateRowView: NSTableRowView {
    static let itemIdentifier = NSUserInterfaceItemIdentifier(String(describing: TemplateRowView.self))
    
    override var isEmphasized: Bool {
        get { isSelected }
        set { }
    }
    
    override func drawSelection(in dirtyRect: NSRect) {
        super.drawSelection(in: dirtyRect)
        if selectionHighlightStyle != .none {
            if isEmphasized {
                guard let ctx = NSGraphicsContext.current?.cgContext else { return }
                ctx.setFillColor(NSAppearance.current.isLight ? NSColor.alternatingContentBackgroundColors[1].cgColor : NSColor.alternatingContentBackgroundColors[0].cgColor)
                ctx.fill(bounds)
            }
        }
    }
}
