//
//  PurchaseButton.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@objc protocol PurchaseButtonDelegate: class {
    func purchaseButtonTapped(_ sender: PurchaseButton)
}

class PurchaseButton: ColoredView {
    
    @IBOutlet weak var titleLabel     : NSTextField!
    @IBOutlet weak var subtitleLabel  : NSTextField!
    @IBOutlet weak var priceLabel     : NSTextField?
    @IBOutlet weak var delegate       : PurchaseButtonDelegate?
    
    var isEnabled: Bool = true {
        didSet {
            backgroundColor = NSColor(named: "PurchaseControlBackground")!
        }
    }
    
    override var mouseDownCanMoveWindow: Bool { false }
    private var shouldTrackMouseUp = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let area = NSTrackingArea.init(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isEnabled {
            backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.1)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        backgroundColor = NSColor(named: "PurchaseControlBackground")!
        shouldTrackMouseUp = false
    }
    
    override func mouseDown(with event: NSEvent) {
        shouldTrackMouseUp = true
    }
    
    override func mouseUp(with event: NSEvent) {
        if shouldTrackMouseUp && bounds.contains(convert(event.locationInWindow, from: nil)) {
            if isEnabled {
                delegate?.purchaseButtonTapped(self)
            }
            shouldTrackMouseUp = false
        }
    }
    
    override func cursorUpdate(with event: NSEvent) {
        if isEnabled {
            NSCursor.pointingHand.set()
        }
    }
    
}
