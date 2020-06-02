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

extension NSColor {
    convenience init(css: Int, alpha: CGFloat) {
        let red = CGFloat((css & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((css & 0xFF00) >> 8) / 255.0
        let blue = CGFloat((css & 0xFF)) / 255.0
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
    convenience init(css: String, alpha: CGFloat) {
        var cleanedString = ""
        if css.hasPrefix("0x") { cleanedString = String(css.dropFirst(2)) }
        else if css.hasPrefix("#") { cleanedString = String(css.dropFirst(1)) }
        var theInt: UInt32 = 0
        let scanner = Scanner(string: cleanedString)
        assert(scanner.scanHexInt32(&theInt))
        self.init(
            calibratedRed: CGFloat((theInt & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((theInt & 0xFF00) >> 8) / 255.0,
            blue: CGFloat((theInt & 0xFF)) / 255.0,
            alpha: alpha
        )
    }
    public var sharpCSS: String {
        guard colorSpace == NSColorSpace.sRGB || colorSpace == NSColorSpace.deviceRGB || colorSpace == NSColorSpace.genericRGB else {
            return "#FFFFFF"
        }
        return String(format: "#%02X%02X%02X", Int(redComponent * 0xFF), Int(greenComponent * 0xFF), Int(blueComponent * 0xFF))
    }
    static var random: NSColor {
        return NSColor(calibratedRed: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1.0)
    }
}
