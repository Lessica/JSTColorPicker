//
//  NSColor+HSV.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/30.
//  Copyright © 2022 JST. All rights reserved.
//

import CoreGraphics

extension Color.RGBA {
    
    var cgColor: CGColor {
        CGColor(red: CGFloat(rgb.r), green: CGFloat(rgb.g), blue: CGFloat(rgb.b), alpha: CGFloat(a))
    }
}

extension Color.GA {
    
    var cgColor: CGColor {
        CGColor(gray: CGFloat(g.w), alpha: CGFloat(a))
    }
}

extension CGColor {
    
    private var isRGBColor: Bool {
        let rgbColorSpaces: [CFString] = [
            CGColorSpace.displayP3, CGColorSpace.adobeRGB1998, CGColorSpace.extendedSRGB, CGColorSpace.sRGB, CGColorSpace.linearSRGB, CGColorSpace.extendedLinearSRGB,
        ]
        if let colorSpaceName = self.colorSpace?.name {
            return rgbColorSpaces.contains(colorSpaceName)
        }
        return false
    }
    
    private var isGrayscaleColor: Bool {
        let grayscaleColorSpaces: [CFString] = [
            CGColorSpace.linearGray, CGColorSpace.extendedGray, CGColorSpace.extendedLinearGray, CGColorSpace.genericGrayGamma2_2,
        ]
        if let colorSpaceName = self.colorSpace?.name {
            return grayscaleColorSpaces.contains(colorSpaceName)
        }
        return false
    }
    
    private var redComponent: CGFloat {
        return components![0]
    }
    
    private var greenComponent: CGFloat {
        return components![1]
    }
    
    private var blueComponent: CGFloat {
        return components![2]
    }
    
    private var whiteComponent: CGFloat {
        return components![0]
    }
    
    var rgba: Color.RGBA {
        
        if isRGBColor {
            return Color.RGBA(r: Float(redComponent), g: Float(greenComponent), b: Float(blueComponent), a: Float(alpha))
        } else if isGrayscaleColor {
            return Color.G(w: Float(whiteComponent)).rgb.rgba(withAlphaComponent: Float(alpha))
        } else {
            fatalError("unsupported color space")
        }
    }
    
    var ga: Color.GA {
        
        if isRGBColor {
            return Color.GA(w: rgba.rgb.grayscale.w, a: Float(alpha))
        } else if isGrayscaleColor {
            return Color.GA(w: Float(whiteComponent), a: Float(alpha))
        } else {
            fatalError("unsupported color space")
        }
    }
}
