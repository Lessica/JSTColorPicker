//
//  TagImportAlertView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2020/6/21.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class TagImportAlertView: NSView {

    @IBOutlet weak var textView: NSTextView!
    
    var text: String {
        get { textView.string            }
        set { textView.string = newValue }
    }
    
}
