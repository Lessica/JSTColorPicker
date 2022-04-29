//
//  NSColor+HSV.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/30.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

extension Color.RGBA {
    
    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: CGFloat(a))
    }
}

extension Color.HSVA {
    
    var nsColor: NSColor {
        NSColor(calibratedHue: CGFloat(hsv.h), saturation: CGFloat(hsv.s), brightness: CGFloat(hsv.v), alpha: CGFloat(a))
    }
}

extension Color.GA {
    
    var nsColor: NSColor {
        NSColor(calibratedWhite: CGFloat(g.w), alpha: CGFloat(a))
    }
}

extension NSColor {
    
    var isRGBColor: Bool {
        let rgbColorSpaces: [NSColorSpace] = [
            .displayP3, .adobeRGB1998, .extendedSRGB, .sRGB, .genericRGB, .deviceRGB,
        ]
        return rgbColorSpaces.contains(self.colorSpace)
    }
    
    var isGrayscaleColor: Bool {
        let grayscaleColorSpaces: [NSColorSpace] = [
            .deviceGray, .genericGray, .genericGamma22Gray, .extendedGenericGamma22Gray,
        ]
        return grayscaleColorSpaces.contains(self.colorSpace)
    }
    
    var rgba: Color.RGBA {
        
        if isRGBColor {
            return Color.RGBA(r: Float(redComponent), g: Float(greenComponent), b: Float(blueComponent), a: Float(alphaComponent))
        } else if isGrayscaleColor {
            return Color.G(w: Float(whiteComponent)).rgb.rgba(withAlphaComponent: Float(alphaComponent))
        } else {
            fatalError("unsupported color space")
        }
    }
    
    var hsva: Color.HSVA {
        
        if isRGBColor {
            return Color.HSVA(h: Float(hueComponent), s: Float(saturationComponent), v: Float(brightnessComponent), a: Float(alphaComponent))
        } else if isGrayscaleColor {
            return Color.G(w: Float(whiteComponent)).hsv.hsva(withAlphaComponent: Float(alphaComponent))
        } else {
            fatalError("unsupported color space")
        }
    }
    
    var ga: Color.GA {
        
        if isRGBColor {
            return Color.GA(w: rgba.rgb.grayscale.w, a: Float(alphaComponent))
        } else if isGrayscaleColor {
            return Color.GA(w: Float(whiteComponent), a: Float(alphaComponent))
        } else {
            fatalError("unsupported color space")
        }
    }
}
