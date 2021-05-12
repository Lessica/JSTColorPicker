//
//  MultipleErrorAlertView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/21.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class MultipleErrorAlertView: NSView {

    @IBOutlet weak var textView: NSTextView!
    
    var text: String {
        get { textView.string            }
        set { textView.string = newValue }
    }
    
}
