//
//  Cocoa+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        // this method is mentioned by: https://developer.apple.com/documentation/appkit/nsscreen/1388360-devicedescription
        return deviceDescription[NSDeviceDescriptionKey.init(rawValue: "NSScreenNumber")] as? CGDirectDisplayID
    }
}

extension NSView {
    @objc func setNeedsDisplay() {
        setNeedsDisplay(bounds)
    }
    func bringToFront() {
        guard let sView = superview else {
            return
        }
        removeFromSuperview()
        sView.addSubview(self)
    }
}

extension NSScrollView {
    func convertFromDocumentView(_ rect: CGRect) -> CGRect {
        return convert(rect, from: documentView)
    }
    func convertFromDocumentView(_ size: CGSize) -> CGSize {
        return convert(size, from: documentView)
    }
    func convertFromDocumentView(_ point: CGPoint) -> CGPoint {
        return convert(point, from: documentView)
    }
    func convertToDocumentView(_ rect: CGRect) -> CGRect {
        return convert(rect, to: documentView)
    }
    func convertToDocumentView(_ size: CGSize) -> CGSize {
        return convert(size, to: documentView)
    }
    func convertToDocumentView(_ point: CGPoint) -> CGPoint {
        return convert(point, to: documentView)
    }
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size, flipped: false) { (rect) -> Bool in
            color.drawSwatch(in: NSRect(origin: .zero, size: rect.size))
            return true
        }
        cacheMode = .never
    }
}

extension String  {
    func conformsTo(pattern: String) -> Bool {
        let pattern = NSPredicate(format:"SELF MATCHES %@", pattern)
        return pattern.evaluate(with: self)
    }
}

extension NSColor {
    class func fromHex(hex: Int, alpha: CGFloat) -> NSColor {
        let red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((hex & 0xFF00) >> 8) / 255.0
        let blue = CGFloat((hex & 0xFF)) / 255.0
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
    class func fromHexString(hex: String, alpha: CGFloat) -> NSColor? {
        // Handle two types of literals: 0x and # prefixed
        var cleanedString = ""
        if hex.hasPrefix("0x") {
            cleanedString = String(hex.dropFirst(2))
        } else if hex.hasPrefix("#") {
            cleanedString = String(hex.dropFirst(1))
        }
        // Ensure it only contains valid hex characters 0
        let validHexPattern = "[a-fA-F0-9]+"
        if cleanedString.conformsTo(pattern: validHexPattern) {
            var theInt: UInt32 = 0
            let scanner = Scanner(string: cleanedString)
            scanner.scanHexInt32(&theInt)
            let red = CGFloat((theInt & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((theInt & 0xFF00) >> 8) / 255.0
            let blue = CGFloat((theInt & 0xFF)) / 255.0
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        } else {
            return nil
        }
    }
}
