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
            titleTextField?.isEnabled = isEditable
            valuePopUpButton?.isEnabled = isEditable
            valueCheckboxButton?.isEnabled = isEditable
            valueStringTextField?.isEditable = isEditable
            valueStringTextField?.isEnabled = isEditable
            valueIntegerTextField?.isEditable = isEditable
            valueIntegerTextField?.isEnabled = isEditable
            valueDecimalTextField?.isEditable = isEditable
            valueDecimalTextField?.isEnabled = isEditable
        }
    }
    
}
