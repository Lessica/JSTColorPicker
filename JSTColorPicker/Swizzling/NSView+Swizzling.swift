//
//  NSView+Swizzling.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/2.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

extension NSView: SwizzlingInjection {
    
    public static func inject() {
        let original = #selector(updateLayer)
        let swizzle = #selector(widget_updateLayer)
        if let widgetClass = NSClassFromString("NSWidgetView"),
           let originalMethod = class_getInstanceMethod(widgetClass, original),
           let swizzleMethod = class_getInstanceMethod(NSView.self, swizzle) {
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
    
    private static var cornerMaskImageAqua: CGImage = {
        let image = NSImage(named: "CACornerMaskAqua")!
        var rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }()
    
    private static var cornerMaskImageDarkAqua: CGImage = {
        let image = NSImage(named: "CACornerMaskDarkAqua")!
        var rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
    }()
    
    @objc func widget_updateLayer() {
        guard let superview = superview, NSStringFromClass(type(of: self)) == "NSWidgetView"
        else {
            // This calls the original implementation so all other NSWidgetViews will have the right look
            self.widget_updateLayer()
            return
        }
        
        if NSStringFromClass(type(of: superview)) == "NSBox" {
            guard let dictionary = self.value(forKey: "widgetDefinition") as? [String: Any], let widget = dictionary["widget"] as? String, widget == "group"
            else {
                self.widget_updateLayer()
                return
            }
            
            self.widget_updateLayer()
            // Remove corner radius with the alternative mask image
            layer?.contents = (NSAppearance.current.name == .vibrantLight || NSAppearance.current.name == .aqua) ? NSView.cornerMaskImageAqua : NSView.cornerMaskImageDarkAqua
        }
        
//        else if NSStringFromClass(type(of: superview)) == "NSToolbarItemViewer" {
//            guard let toolbarItem = superview.value(forKeyPath: "_item") as? NSToolbarItem, !toolbarItem.itemIdentifier.rawValue.hasPrefix("com.apple.")
//            else {
//                self.widget_updateLayer()
//                return
//            }
//            
//            // Remove background
//        }
        
        else {
            self.widget_updateLayer()
        }
    }
}
