//
//  PixelImage.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
import LuaSwift

enum PixelImageError: LocalizedError {
    case readFailed
    case loadSourceFailed
    case loadImageFailed
    
    var failureReason: String? {
        switch self {
        case .readFailed:
            return NSLocalizedString("File read failed.", comment: "PixelImageError")
        case .loadSourceFailed:
            return NSLocalizedString("Load image source failed.", comment: "PixelImageError")
        case .loadImageFailed:
            return NSLocalizedString("Load image data failed.", comment: "PixelImageError")
        }
    }
}

class PixelImage {
    
    var imageURL: URL
    var imageRep: CGImage
    var imageSourceRep: CGImageSource
    var pixelImageRep: JSTPixelImage
    
    init(contentsOf url: URL) throws {
        guard let dataProvider = CGDataProvider(filename: url.path) else {
            throw PixelImageError.readFailed
        }
        let imageSourceOptions = [kCGImageSourceShouldCache: true] as CFDictionary
        guard let cgimgSource = CGImageSourceCreateWithDataProvider(dataProvider, imageSourceOptions) else {
            throw PixelImageError.loadSourceFailed
        }
        guard let cgimg = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw PixelImageError.loadImageFailed
        }
        
        self.imageURL       = url
        self.imageRep       = cgimg
        self.imageSourceRep = cgimgSource
        self.pixelImageRep  = JSTPixelImage(cgImage: cgimg)
    }
    
    var size: PixelSize {
        return PixelSize(pixelImageRep.size)
    }
    
    var bounds: PixelRect {
        return PixelRect(origin: .zero, size: size)
    }
    
    func color(at coordinate: PixelCoordinate) -> PixelColor? {
        guard bounds.contains(coordinate) else { return nil }
        return PixelColor(coordinate: coordinate, color: pixelImageRep.getJSTColor(of: coordinate.toCGPoint()))
    }
    
    func area(at rect: PixelRect) -> PixelArea? {
        guard bounds.contains(rect) else { return nil }
        return PixelArea(rect: rect)
    }
    
    func pngRepresentation() -> Data {
        return pixelImageRep.pngRepresentation()
    }
    
    func pngRepresentation(of area: PixelArea) -> Data? {
        guard bounds.contains(area.rect) else { return nil }
        return pixelImageRep.crop(area.rect.toCGRect()).pngRepresentation()
    }
    
    func toNSImage() -> NSImage {
        return pixelImageRep.toNSImage()
    }
    
    func toNSImage(of area: PixelArea) -> NSImage? {
        guard bounds.contains(area.rect) else { return nil }
        return pixelImageRep.crop(area.rect.toCGRect()).toNSImage()
    }
    
    func downsample(to pointSize: CGSize, scale: CGFloat) -> NSImage {
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions =  [
            // kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
            ] as CFDictionary
        let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSourceRep, 0, downsampleOptions)!
        return NSImage(cgImage: downsampledImage, size: pointSize)
    }
    
    deinit {
        debugPrint("- [PixelImage deinit]")
    }
    
}

extension PixelImage: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine) {
        let t = vm.createTable()
        t["w"] = size.width
        t["h"] = size.height
        t["get_color"] = vm.createFunction([ Int64.arg, Int64.arg ], { (args) -> SwiftReturnValue in
            let (x, y) = (args.integer, args.integer)
            let coordinate = PixelCoordinate(x: Int(x), y: Int(y))
            if let color = self.color(at: coordinate)?.rgbaValue {
                return .value(color)
            }
            else {
                return .error(ContentError.itemOutOfRange(item: coordinate, range: self.size).failureReason!)
            }
        })
        t["get_image"] = vm.createFunction([ Int64.arg, Int64.arg, Int64.arg, Int64.arg ], { (args) -> SwiftReturnValue in
            let (x, y, w, h) = (args.integer, args.integer, args.integer, args.integer)
            let area = PixelArea(rect: PixelRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
            if let data = self.pngRepresentation(of: area) {
                return .value(data)
            }
            else {
                return .error(ContentError.itemOutOfRange(item: area, range: self.size).failureReason!)
            }
        })
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    fileprivate static let typeName: String = "pixel image (table with keys [w,h,get_color,get_image])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if !(t["w"] is Number) || !(t["h"] is Number) || !(t["get_color"] is Function) || !(t["get_image"] is Function) { return typeName }
        return nil
    }
    
}
