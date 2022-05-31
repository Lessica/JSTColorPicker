//
//  PixelImage.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa
#if WITH_LUASWIFT
import LuaSwift
#endif

final class PixelImage {
    
    struct Source {
        var url: URL
        var cgSource: CGImageSource
    }
    
    enum Error: CustomNSError, LocalizedError {
        
        case readFailed(_ url: URL)
        case loadSourceFailed(_ url: URL)
        case loadImageFailed(_ url: URL)
        
        var errorCode: Int {
            switch self {
                case .readFailed(_):
                    return 201
                case .loadSourceFailed(_):
                    return 202
                case .loadImageFailed(_):
                    return 203
            }
        }
        
        var failureReason: String? {
            switch self {
                case .readFailed(let url):
                    return String(format: NSLocalizedString("File read failed: %@.", comment: "PixelImageError"), url.path)
                case .loadSourceFailed(let url):
                    return String(format: NSLocalizedString("Load image source failed: %@.", comment: "PixelImageError"), url.path)
                case .loadImageFailed(let url):
                    return String(format: NSLocalizedString("Load image data failed: %@.", comment: "PixelImageError"), url.path)
            }
        }
        
    }
    
    public fileprivate(set) var cgImage: CGImage
    public fileprivate(set) var imageSource: Source
    public fileprivate(set) var pixelImageRepresentation: JSTPixelImage
    public func rename(to url: URL) { imageSource.url = url }
    
    public init(contentsOf url: URL) throws {
        guard let dataProvider = CGDataProvider(filename: url.path) else {
            throw PixelImage.Error.readFailed(url)
        }
        let imageSourceOptions = [kCGImageSourceShouldCache: true] as CFDictionary
        guard let cgimgSource = CGImageSourceCreateWithDataProvider(dataProvider, imageSourceOptions) else {
            throw PixelImage.Error.loadSourceFailed(url)
        }
        
        var imageLoader: CGImage? = nil
        if let cgimg = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            imageLoader = cgimg
        }
        if imageLoader == nil,
           let data = dataProvider.data as Data?,
           let image = NSImage(data: data), let cgimg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        {
            imageLoader = cgimg
        }
        
        guard let cgimg = imageLoader else {
            throw PixelImage.Error.loadImageFailed(url)
        }
        
        self.cgImage                   = cgimg
        self.imageSource               = Source(url: url, cgSource: cgimgSource)
        self.pixelImageRepresentation  = JSTPixelImage(cgImage: cgimg)
    }
    
    public var size: PixelSize { PixelSize(pixelImageRepresentation.size) }
    
    public var bounds: PixelRect { PixelRect(origin: .zero, size: size) }
    
    public var colorSpace: NSColorSpace { NSColorSpace(cgColorSpace: pixelImageRepresentation.colorSpace)! }
    
    public var cgColorSpace: CGColorSpace { pixelImageRepresentation.colorSpace }
    
    public func rawColor(at coordinate: PixelCoordinate) -> JSTPixelColor? {
        guard bounds.contains(coordinate) else { return nil }
        return pixelImageRepresentation.getJSTColor(of: coordinate.toCGPoint())
    }
    
    public func color(at coordinate: PixelCoordinate) -> PixelColor? {
        guard let rawColor = rawColor(at: coordinate) else { return nil }
        return PixelColor(coordinate: coordinate, color: rawColor)
    }
    
    public func area(at rect: PixelRect) -> PixelArea? {
        guard bounds.contains(rect) else { return nil }
        return PixelArea(rect: rect)
    }
    
    public func pngRepresentation() -> Data {
        return pixelImageRepresentation.pngRepresentation()
    }
    
    public func pngRepresentation(of area: PixelArea) -> Data? {
        guard bounds.contains(area.rect) else { return nil }
        return pixelImageRepresentation.crop(area.rect.toCGRect()).pngRepresentation()
    }
    
    public func toNSImage() -> NSImage {
        return pixelImageRepresentation.toSystemImage()
    }
    
    public func toNSImage(of area: PixelArea) -> NSImage? {
        guard bounds.contains(area.rect) else { return nil }
        return pixelImageRepresentation.crop(area.rect.toCGRect()).toSystemImage()
    }
    
    public func downsample(to pointSize: CGSize, scale: CGFloat) -> NSImage {
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions =  [
            // kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource.cgSource, 0, downsampleOptions)!
        return NSImage(cgImage: downsampledImage, size: pointSize)
    }
    
}

#if WITH_LUASWIFT
extension PixelImage: LuaSwift.Value {
    
    func push(_ vm: VirtualMachine)
    {
        let t = vm.createTable()
        let imageURL = imageSource.url
        
        t["type"] = String(describing: PixelImage.self)
        
        t["path"] = imageURL.path
        t["folder"] = imageURL.deletingLastPathComponent().lastPathComponent
        t["filename"] = imageURL.lastPathComponent
        t["extension"] = imageURL.pathExtension.lowercased()
        
        t["width"] = size.width
        t["height"] = size.height
        t["size"] = size
        
        t["get_color"] = vm.createFunction([Int64.arg, Int64.arg], requiredArgumentCount: 2) {
            (args) -> SwiftReturnValue in
            
            let (x, y) = (args.integer, args.integer)
            let coordinate = PixelCoordinate(x: Int(x), y: Int(y))
            if let color = self.rawColor(at: coordinate)?.rgbaValue {
                return .value(color)
            }
            else {
                return .error(Content.Error.itemOutOfRange(item: coordinate, range: self.size).failureReason!)
            }
        }
        
        t["get_image"] = vm.createFunction([Int64.arg, Int64.arg, Int64.arg, Int64.arg], requiredArgumentCount: 4) {
            (args) -> SwiftReturnValue in
            
            let (x, y, w, h) = (args.integer, args.integer, args.integer, args.integer)
            let area = PixelArea(rect: PixelRect(x: Int(x), y: Int(y), width: Int(w), height: Int(h)))
            if let data = self.pngRepresentation(of: area) {
                return .value(data)
            }
            else {
                return .error(Content.Error.itemOutOfRange(item: area, range: self.size).failureReason!)
            }
        }
        
        t["get_data"] = vm.createFunction([Bool.arg], requiredArgumentCount: 0) {
            (args) -> SwiftReturnValue in
            
            var withMetadata = false
            if args.count == 1 {
                withMetadata = args.boolean
            }
            
            if withMetadata {
                if let screenshots = ScreenshotController.shared.documents as? [Screenshot] {
                    if let screenshot = screenshots.filter({ $0.image === self }).first,
                       let documentType = screenshot.fileType,
                       let screenshotData = try? screenshot.data(ofType: documentType)
                    {
                        return .value(screenshotData)
                    }
                }
                return .error(Content.Error.notLoaded.failureReason!)
            } else {
                return .value(self.pngRepresentation())
            }
        }
        
        t.push(vm)
    }
    
    func kind() -> Kind { return .table }
    
    private static let typeKeys: [String] = [
        "type", "path", "folder",
        "filename", "extension",
        "width", "height",
        "get_color", "get_image"
    ]
    private static let typeName: String = "\(String(describing: PixelImage.self)) (Table Keys [\(typeKeys.joined(separator: ","))])"
    class func arg(_ vm: VirtualMachine, value: Value) -> String? {
        if value.kind() != .table { return typeName }
        if let result = Table.arg(vm, value: value) { return result }
        let t = value as! Table
        if  !(t["type"] is String)              ||
                !(t["path"] is String)          ||
                !(t["folder"] is String)        ||
                !(t["filename"] is String)      ||
                !(t["extension"] is String)     ||
                !(t["width"] is Number)         ||
                !(t["height"] is Number)        ||
                !(t["get_color"] is Function)   ||
                !(t["get_image"] is Function)
        {
            return typeName
        }
        return nil
    }
    
}
#endif
