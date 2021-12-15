//
//  PixelMatch.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

public struct MatchOptions {
    
    public var threshold: CGFloat = 0.1                          // matching threshold (0 to 1); smaller is more sensitive
    public var includeAA: Bool = false                           // whether to skip anti-aliasing detection
    public var alpha: CGFloat = 0.5                              // opacity of original image in diff ouput
    public var aaColor: (UInt8, UInt8, UInt8) = (255, 255, 0)    // color of anti-aliased pixels in diff output
    public var diffColor: (UInt8, UInt8, UInt8) = (255, 0, 0)    // color of different pixels in diff output
    public var diffMask: Bool = false                            // draw the diff over a transparent background (a mask)
    public var maximumThreadCount: Int = 32                      // maximum concurrent jobs count
    public var verbose: Bool = false                             // enable verbose logging
    
}

public func PixelMatch(a32: inout [JST_COLOR], b32: inout [JST_COLOR], output: inout [JST_COLOR], width: Int, height: Int, options: MatchOptions) throws -> Int {
    
    enum Error: LocalizedError {
        
        case sizesDoNotMatch
        
        var failureReason: String? {
            switch self {
            case .sizesDoNotMatch:
                return NSLocalizedString("Image sizes do not match.", comment: "PixelMatchError")
            }
        }
        
    }
    
    guard a32.count == b32.count else { throw Error.sizesDoNotMatch }
    guard a32.count == width * height else { throw Error.sizesDoNotMatch }
    
    // check if images are identical
    let len = width * height
    var identical = true
    for i in 0..<len {
        if a32[i].the_color != b32[i].the_color { identical = false; break; }
    }
    if identical { // fast path if identical
        if !options.diffMask {
            for i in 0..<len { drawGrayPixel(color: a32[i], pos: i, alpha: options.alpha, output: &output) }
        }
        return 0
    }
    
    // maximum acceptable square distance between two colors;
    // 35215 is the maximum possible value for the YIQ difference metric
    let maxDelta = 35215 * options.threshold * options.threshold
    
    var diff = 0
    let (aaR, aaG, aaB) = options.aaColor
    let (diffR, diffG, diffB) = options.diffColor
    
    // compare each pixel of one image against the other one
    for y in 0..<height {
        for x in 0..<width {
            
            let pos = y * width + x
            
            // squared YUV distance between colors at this pixel position
            let delta = colorDelta(color1: a32[pos], color2: b32[pos])
            
            // the color difference is above the threshold
            if delta > maxDelta {
                // check it's a real rendering difference or just anti-aliasing
                if !options.includeAA && (antialiased(img: &a32, x1: x, y1: y, width: width, height: height, img2: &b32) ||
                    antialiased(img: &b32, x1: x, y1: y, width: width, height: height, img2: &a32)) {
                    // one of the pixels is anti-aliasing; draw as yellow and do not count as difference
                    // note that we do not include such pixels in a mask
                    if !options.diffMask { drawPixel(output: &output, pos: pos, r: aaR, g: aaG, b: aaB) }
                    
                } else {
                    // found substantial difference not caused by anti-aliasing; draw it as red
                    drawPixel(output: &output, pos: pos, r: diffR, g: diffG, b: diffB)
                    diff += 1
                }
                
            } else {
                // pixels are similar; draw background as grayscale image blended with white
                if !options.diffMask { drawGrayPixel(color: a32[pos], pos: pos, alpha: options.alpha, output: &output) }
            }
        }
    }
    
    // return the number of different pixels
    return diff
}

// check if a pixel is likely a part of anti-aliasing;
// based on "Anti-aliased Pixel and Intensity Slope Detector" paper by V. Vysniauskas, 2009

private func antialiased(img: inout [JST_COLOR], x1: Int, y1: Int, width: Int, height: Int, img2: inout [JST_COLOR]) -> Bool {
    let x0 = max(x1 - 1, 0), y0 = max(y1 - 1, 0)
    let x2 = min(x1 + 1, width - 1), y2 = min(y1 + 1, height - 1)
    let pos = y1 * width + x1
    var zeroes = x1 == x0 || x1 == x2 || y1 == y0 || y1 == y2 ? 1 : 0
    
    var min: CGFloat = 0, max: CGFloat = 0
    var minX: Int!, minY: Int!, maxX: Int!, maxY: Int!
    
    // go through 8 adjacent pixels
    for x in x0...x2 {
        for y in y0...y2 {
            if x == x1 && y == y1 { continue }
            
            // brightness delta between the center pixel and adjacent one
            let delta = colorDelta(color1: img[pos], color2: img[y * width + x], yOnly: true)
            
            // count the number of equal, darker and brighter adjacent pixels
            if delta == 0 {
                zeroes += 1
                // if found more than 2 equal siblings, it's definitely not anti-aliasing
                if zeroes > 2 { return false }
                
                // remember the darkest pixel
            } else if delta < min {
                min = delta
                minX = x
                minY = y
                
                // remember the brightest pixel
            } else if delta > max {
                max = delta
                maxX = x
                maxY = y
            }
        }
    }
    
    // if there are no both darker and brighter pixels among siblings, it's not anti-aliasing
    if min == 0 || max == 0 { return false }
    
    // if either the darkest or the brightest pixel has 3+ equal siblings in both images
    // (definitely not anti-aliased), this pixel is anti-aliased
    return (hasManySiblings(img: &img, x1: minX, y1: minY, width: width, height: height) && hasManySiblings(img: &img2, x1: minX, y1: minY, width: width, height: height)) ||
        (hasManySiblings(img: &img, x1: maxX, y1: maxY, width: width, height: height) && hasManySiblings(img: &img2, x1: maxX, y1: maxY, width: width, height: height))
}

private func hasManySiblings(img: inout [JST_COLOR], x1: Int, y1: Int, width: Int, height: Int) -> Bool {
    let x0 = max(x1 - 1, 0), y0 = max(y1 - 1, 0)
    let x2 = min(x1 + 1, width - 1), y2 = min(y1 + 1, height - 1)
    let pos = y1 * width + x1
    var zeroes = x1 == x0 || x1 == x2 || y1 == y0 || y1 == y2 ? 1 : 0
    
    // go through 8 adjacent pixels
    for x in x0...x2 {
        for y in y0...y2 {
            if x == x1 && y == y1 { continue }
            
            let pos2 = y * width + x
            if img[pos].the_color == img[pos2].the_color { zeroes += 1 }
            if zeroes > 2 { return true }
        }
    }
    
    return false
}

// calculate color difference according to the paper "Measuring perceived color difference
// using YIQ NTSC transmission color space in mobile applications" by Y. Kotsarenko and F. Ramos

private func colorDelta(color1: JST_COLOR, color2: JST_COLOR, yOnly: Bool = false) -> CGFloat {
    if color1.the_color == color2.the_color { return 0 }
    
    var a1 = CGFloat(color1.alpha)
    , r1 = CGFloat(color1.red)
    , g1 = CGFloat(color1.green)
    , b1 = CGFloat(color1.blue)
    
    var a2 = CGFloat(color2.alpha)
    , r2 = CGFloat(color2.red)
    , g2 = CGFloat(color2.green)
    , b2 = CGFloat(color2.blue)
    
    if a1 < 255.0 {
        a1 /= 255.0
        r1 = blend(r1, a1)
        g1 = blend(g1, a1)
        b1 = blend(b1, a1)
    }
    
    if a2 < 255.0 {
        a2 /= 255.0
        r2 = blend(r2, a2)
        g2 = blend(g2, a2)
        b2 = blend(b2, a2)
    }
    
    let y = rgb2y(r1, g1, b1) - rgb2y(r2, g2, b2)
    if yOnly { return y }
    let i = rgb2i(r1, g1, b1) - rgb2i(r2, g2, b2)
    let q = rgb2q(r1, g1, b1) - rgb2q(r2, g2, b2)
    
    return 0.5053 * y * y + 0.299 * i * i + 0.1957 * q * q 
}

private func rgb2y(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat { return (r * 0.29889531) + (g * 0.58662247) + (b * 0.11448223) }
private func rgb2i(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat { return (r * 0.59597799) - (g * 0.27417610) - (b * 0.32180189) }
private func rgb2q(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGFloat { return (r * 0.21147017) - (g * 0.52261711) + (b * 0.31114694) }

// blend semi-transparent color with white
private func blend(_ component: CGFloat, _ alpha: CGFloat) -> CGFloat   { return 255.0 + (component - 255.0) * alpha }
private func drawPixel(output: inout [JST_COLOR], pos: Int, r: UInt8, g: UInt8, b: UInt8) {
    output[pos] = JST_COLOR(the_color: 0xff000000 | UInt32(b) << 16 | UInt32(g) << 8 | UInt32(r))
}
private func drawGrayPixel(color: JST_COLOR, pos: Int, alpha: CGFloat, output: inout [JST_COLOR]) {
    let val = UInt8(blend(rgb2y(CGFloat(color.red), CGFloat(color.green), CGFloat(color.blue)), alpha * CGFloat(color.alpha) / 255.0))
    drawPixel(output: &output, pos: pos, r: val, g: val, b: val)
}
