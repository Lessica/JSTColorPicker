//
//  TemplateContentCellView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/16.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class TemplateContentCellView: NSTableCellView {
    
    static let defaultFontSize        : CGFloat = 11.0
    static let defaultTextAttributes  : [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: defaultFontSize, weight: .regular),
        .foregroundColor: NSColor.labelColor,
    ]
    static let disabledTextAttributes : [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: defaultFontSize, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor,
    ]

    var text: String? {
        get { textField?.stringValue }
        set { textField?.stringValue = newValue ?? "" }
    }
    
    var attributedText: NSAttributedString? {
        get { textField?.attributedStringValue }
        set { textField?.attributedStringValue = newValue ?? NSAttributedString(string: "", attributes: TemplateContentCellView.defaultTextAttributes) }
    }

    var image: NSImage? {
        get { imageView?.image            }
        set { imageView?.image = newValue }
    }

    var maximumNumberOfLines: Int? {
        get { textField?.maximumNumberOfLines }
        set { textField?.maximumNumberOfLines = min(max(newValue ?? 20, 5), 99) }
    }
    
    override var backgroundStyle: NSView.BackgroundStyle {
        get { .normal }
        set { }
    }
    
}
