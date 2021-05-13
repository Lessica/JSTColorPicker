//
//  TagCellView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/15.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagCellView: NSTableCellView {
    
    var text: String? {
        get { textField?.stringValue                  }
        set { textField?.stringValue = newValue ?? "" }
    }
    
    var image: NSImage? {
        get { imageView?.image            }
        set { imageView?.image = newValue }
    }
    
    var isEnabled: Bool {
        get {
            if checkbox != nil {
                return checkbox?.isEnabled ?? false
            }
            else if textField != nil {
                return textField?.isEnabled ?? false
            }
            return false
        }
        set {
            if checkbox != nil {
                checkbox?.isEnabled = newValue
            }
            else if textField != nil {
                textField?.isEnabled = newValue
            }
        }
    }
    
    var isEditable: Bool {
        get {
            if checkbox != nil {
                return checkbox?.isEnabled ?? false
            }
            else if textField != nil {
                return textField?.isEditable ?? false
            }
            return false
        }
        set {
            if checkbox != nil {
                checkbox?.isEnabled = newValue
            }
            else if textField != nil {
                textField?.isEditable = newValue
            }
        }
    }
    
    var state: NSControl.StateValue {
        get {
            if checkbox != nil {
                return checkbox?.state ?? .off
            }
            return .off
        }
        set {
            if checkbox != nil {
                checkbox?.state = newValue
            }
        }
    }
    
    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            guard let tag = objectValue as? Tag else { return }
            if backgroundStyle == .emphasized {
                textField?.textColor = .white
            } else {
                textField?.textColor = tag.color
            }
        }
    }
    
    
    // MARK: - Checkbox
    
    @IBOutlet weak var checkbox: NSButton?
    
}
