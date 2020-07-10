//
//  AlertTextView.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/21.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class AlertTextView: NSView {

    @IBOutlet public weak var textView: NSTextView!
    
    public var text: String {
        get { textView.string            }
        set { textView.string = newValue }
    }
    
}
