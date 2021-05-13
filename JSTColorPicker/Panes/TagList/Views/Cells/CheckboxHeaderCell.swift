//
//  CheckboxHeaderCell.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/26.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class CheckboxCell: NSButtonCell {
    var alternateState: NSControl.StateValue = .off {
        didSet {
            super.state = alternateState
        }
    }
    override var state: NSControl.StateValue {
        get { alternateState }
        set { }
    }
}

final class CheckboxHeaderCell: NSTableHeaderCell {
    private lazy var innerCell: CheckboxCell = {
        let cell = CheckboxCell()
        cell.title = ""
        cell.setButtonType(.switch)
        cell.type = .nullCellType
        cell.isBordered = false
        cell.imagePosition = .imageOnly
        cell.alignment = .center
        cell.objectValue = NSNumber(booleanLiteral: false)
        cell.controlSize = .regular
        cell.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        cell.allowsMixedState = true
        return cell
    }()
    
    override var textColor: NSColor? {
        get { .clear }
        set { }
    }
    
    override var title: String {
        get { innerCell.title }
        set { innerCell.title = newValue }
    }
    
    override var image: NSImage? {
        get { innerCell.image }
        set { innerCell.image = newValue }
    }
    
    var alternateState: NSControl.StateValue {
        get { innerCell.alternateState }
        set { innerCell.alternateState = newValue }
    }
    
    func toggleAlternateState() -> NSControl.StateValue {
        innerCell.alternateState = (alternateState != .on ? .on : .off)
        return innerCell.alternateState
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: cellFrame, in: controlView)
        let centeredRect = CGRect(
            x: cellFrame.midX - innerCell.cellSize.width / 2.0,
            y: cellFrame.midY - innerCell.cellSize.height / 2.0,
            width: innerCell.cellSize.width,
            height: innerCell.cellSize.height
        )
        innerCell.draw(withFrame: centeredRect, in: controlView)
    }
}
