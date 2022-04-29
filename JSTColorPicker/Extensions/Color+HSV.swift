//
//  HSV.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/13/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

enum Color {
    
    // https://www.cs.rit.edu/~ncs/color/t_convert.html
    struct RGB {
        // Percent
        let r: Float // [0,1]
        let g: Float // [0,1]
        let b: Float // [0,1]

        static func hsv(r: Float, g: Float, b: Float) -> HSV {
            let min = r < g ? (r < b ? r : b) : (g < b ? g : b)
            let max = r > g ? (r > b ? r : b) : (g > b ? g : b)

            let v = max
            let delta = max - min

            guard delta > 0.00001 else { return HSV(h: 0, s: 0, v: max) }
            guard max > 0 else { return HSV(h: -1, s: 0, v: v) } // Undefined, achromatic grey
            let s = delta / max

            let hue: (Float, Float) -> Float = { max, delta -> Float in
                if r == max { return (g - b) / delta } // between yellow & magenta
                else if g == max { return 2 + (b - r) / delta } // between cyan & yellow
                else { return 4 + (r - g) / delta } // between magenta & cyan
            }

            let h = hue(max, delta) * 60 // In degrees

            return HSV(h: h < 0 ? h + 360 : h, s: s, v: v)
        }
        
        static func rgba(rgb: RGB, alpha: Float) -> RGBA {
            return RGBA(r: rgb.r, g: rgb.g, b: rgb.b, a: alpha)
        }

        static func hsv(rgb: RGB) -> HSV {
            return hsv(r: rgb.r, g: rgb.g, b: rgb.b)
        }

        static func grayscale(rgb: RGB) -> G {
            return G(w: 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b)
        }
        
        func rgba(withAlphaComponent alpha: Float) -> RGBA {
            return Self.rgba(rgb: self, alpha: alpha)
        }

        var hsv: HSV {
            return Self.hsv(rgb: self)
        }

        var grayscale: G {
            return Self.grayscale(rgb: self)
        }
    }

    struct RGBA {
        let a: Float
        let rgb: RGB

        init(r: Float, g: Float, b: Float, a: Float) {
            self.a = a
            self.rgb = RGB(r: r, g: g, b: b)
        }
    }

    struct HSV {
        let h: Float // Angle in degrees [0,360] or -1 as Undefined
        let s: Float // Percent [0,1]
        let v: Float // Percent [0,1]

        static func rgb(h: Float, s: Float, v: Float) -> RGB {
            if s == 0 { return RGB(r: v, g: v, b: v) } // Achromatic grey

            let angle = (h >= 360 ? 0 : h)
            let sector = angle / 60 // Sector
            let i = floor(sector)
            let f = sector - i // Factorial part of h

            let p = v * (1 - s)
            let q = v * (1 - (s * f))
            let t = v * (1 - (s * (1 - f)))

            switch i {
            case 0:
                return RGB(r: v, g: t, b: p)
            case 1:
                return RGB(r: q, g: v, b: p)
            case 2:
                return RGB(r: p, g: v, b: t)
            case 3:
                return RGB(r: p, g: q, b: v)
            case 4:
                return RGB(r: t, g: p, b: v)
            default:
                return RGB(r: v, g: p, b: q)
            }
        }
        
        static func hsva(hsv: HSV, alpha: Float) -> HSVA {
            return HSVA(h: hsv.h, s: hsv.s, v: hsv.v, a: alpha)
        }

        static func rgb(hsv: HSV) -> RGB {
            return rgb(h: hsv.h, s: hsv.s, v: hsv.v)
        }
        
        static func grayscale(hsv: HSV) -> G {
            return hsv.rgb.grayscale
        }
        
        func hsva(withAlphaComponent alpha: Float) -> HSVA {
            return Self.hsva(hsv: self, alpha: alpha)
        }

        var rgb: RGB {
            return Self.rgb(hsv: self)
        }
        
        var grayscale: G {
            return Self.grayscale(hsv: self)
        }

        /// Returns a normalized point with x=h and y=v
        var point: CGPoint {
            return CGPoint(x: CGFloat(h / 360), y: CGFloat(v))
        }
    }
    
    struct HSVA {
        let a: Float
        let hsv: HSV

        init(h: Float, s: Float, v: Float, a: Float) {
            self.a = a
            self.hsv = HSV(h: h, s: s, v: v)
        }
    }

    struct G {
        let w: Float

        init(w: Float) {
            self.w = w
        }
        
        static func ga(grayscale: G, alpha: Float) -> GA {
            return GA(w: grayscale.w, a: alpha)
        }
        
        static func rgb(grayscale: G) -> RGB {
            return RGB(r: grayscale.w, g: grayscale.w, b: grayscale.w)
        }
        
        static func hsv(grayscale: G) -> HSV {
            return RGB(r: grayscale.w, g: grayscale.w, b: grayscale.w).hsv
        }
        
        func ga(withAlphaComponent alpha: Float) -> GA {
            return Self.ga(grayscale: self, alpha: alpha)
        }
        
        var rgb: RGB {
            return Self.rgb(grayscale: self)
        }
        
        var hsv: HSV {
            return Self.hsv(grayscale: self)
        }
    }

    struct GA {
        let a: Float
        let g: G

        init(w: Float, a: Float) {
            self.a = a
            g = G(w: w)
        }
    }
}
