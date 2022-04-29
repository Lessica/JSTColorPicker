//
//  NSView+Swizzling.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/2.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

extension NSView: SwizzlingInjection {
    
    static func inject() {
        if let widgetClass = NSClassFromString("NSWidgetView"),
           let originalMethod = class_getInstanceMethod(widgetClass, #selector(updateLayer)),
           let swizzleMethod = class_getInstanceMethod(NSView.self, #selector(widget_updateLayer))
        {
            method_exchangeImplementations(originalMethod, swizzleMethod)
        }
    }
    
    #if DEBUG
    @discardableResult func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    #endif
    
    
    
    @objc func widget_updateLayer() {
        guard let superview = superview, NSStringFromClass(type(of: self)) == "NSWidgetView"
        else {
            // This calls the original implementation so all other NSWidgetViews will have the right look
            self.widget_updateLayer()
            return
        }
        
        if NSStringFromClass(type(of: superview)) == "JSTColorPicker.ClearBox" {
            guard let dictionary = self.value(forKey: "widgetDefinition") as? [String: Any],
                  let widget = dictionary["widget"] as? String, widget == "group"
            else {
                self.widget_updateLayer()
                return
            }
            
            self.widget_updateLayer()
            
            // Remove corner radius with the alternative mask image
            layer?.contents = effectiveAppearance.isLight
                ? ClearBox.cornerMaskImageAqua
                : ClearBox.cornerMaskImageDarkAqua
        }
        
        else {
            self.widget_updateLayer()
        }
    }
}
