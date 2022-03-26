//
//  EditAssociatedValuesTableViewCell.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/3/26.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

class EditAssociatedValuesTableViewCell: NSTableCellView {
    
    @IBOutlet weak var titleTextField: NSTextField?
    @IBOutlet weak var valuePopUpButton: NSPopUpButton?
    @IBOutlet weak var valueCheckboxButton: NSButton?
    
    @IBOutlet weak var valueStringTextField: NSTextField?
    @IBOutlet weak var valueIntegerTextField: NSTextField?
    @IBOutlet weak var valueDecimalTextField: NSTextField?
    
    var isEditable: Bool = true {
        didSet {
            titleTextField?.isEditable = isEditable
            valuePopUpButton?.isEnabled = isEditable
            valueCheckboxButton?.isEnabled = isEditable
            valueStringTextField?.isEditable = isEditable
            valueIntegerTextField?.isEditable = isEditable
            valueDecimalTextField?.isEditable = isEditable
        }
    }
    
}
