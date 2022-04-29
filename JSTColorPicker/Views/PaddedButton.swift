//
//  PaddedButton.swift
//  PillowTalk
//
//  Created by Darwin on 2020/12/17.
//

import Cocoa

final class PaddedButton: NSButton {
    
    @IBInspectable var horizontalPadding   : CGFloat = 0
    @IBInspectable var verticalPadding     : CGFloat = 0
    
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += self.horizontalPadding
        size.height += self.verticalPadding
        return size;
    }
    
}
