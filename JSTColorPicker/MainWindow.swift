//
//  MainWindow.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class MainWindow: NSWindow {

    static let VisibilityDidChangeNotification = NSNotification.Name("MainWindow.VisibilityDidChangeNotification")

    private var firstResponderObservation  : NSKeyValueObservation?
    private var windowVisibleObservation   : NSKeyValueObservation?

    @objc dynamic var isTabbingVisible = false

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
        windowVisibleObservation = observe(\.isVisible, changeHandler: { [weak self] (target, change) in
            self?.stateChanged()
        })
    }

    override func becomeKey() {
        super.becomeKey()
        stateChanged()
    }

    override func becomeMain() {
        super.becomeMain()
        stateChanged()
    }

    override func resignKey() {
        super.resignKey()
        stateChanged()
    }

    override func resignMain() {
        super.resignMain()
        stateChanged()
    }

    private func stateChanged() {
        isTabbingVisible = isKeyWindow || isMainWindow || (isVisible && tabGroup?.selectedWindow == self)
        NotificationCenter.default.post(name: MainWindow.VisibilityDidChangeNotification, object: self)
    }
}
