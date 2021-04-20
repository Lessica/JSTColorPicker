//
//  TemplateContentCellView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/16.
//  Copyright © 2021 JST. All rights reserved.
//

class TemplateContentCellView: NSTableCellView {
    
    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular),
        .foregroundColor: NSColor.labelColor,
    ]

    var text: String? {
        get { textField?.stringValue }
        set { textField?.attributedStringValue = NSAttributedString(string: newValue ?? "", attributes: TemplateContentCellView.textAttributes) }
    }

    var image: NSImage? {
        get { imageView?.image            }
        set { imageView?.image = newValue }
    }

    var maximumNumberOfLines: Int? {
        get { textField?.maximumNumberOfLines }
        set { textField?.maximumNumberOfLines = min(max(newValue ?? 20, 5), 99) }
    }
    
}
