//
//  MainWindow.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class MainWindow: NSWindow {
    private var firstResponderObservation: NSKeyValueObservation?
    override func awakeFromNib() {
        super.awakeFromNib()
        firstResponderObservation = observe(\.firstResponder, options: [.new], changeHandler: { (target, change) in
            guard let firstResponder = change.newValue as? NSResponder else { return }
            debugPrint("First Responder: \(firstResponder)")
            if firstResponder == target {
                // Oops!
                target.selectNextKeyView(target)
            }
        })
    }
}
