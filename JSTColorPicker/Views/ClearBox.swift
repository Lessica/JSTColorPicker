//
//  ClearBox.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/28/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class ClearBox: NSBox {
    
    static var cornerMaskImageAqua: CGImage = {
        let image = NSImage(named: "CACornerMaskAqua")!
        var rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }()
    
    static var cornerMaskImageDarkAqua: CGImage = {
        let image = NSImage(named: "CACornerMaskDarkAqua")!
        var rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }()
    
    override func didAddSubview(_ subview: NSView) {
        if NSStringFromClass(type(of: subview)) == "NSWidgetView" {
            
            // Remove corner radius with the alternative mask image
            if subview.layer == nil {
                subview.wantsLayer = true
                subview.layer?.contents = effectiveAppearance.isLight
                    ? ClearBox.cornerMaskImageAqua
                    : ClearBox.cornerMaskImageDarkAqua
            }
        }
        
        super.didAddSubview(subview)
        
        
    }
}
