//
//  PixelImage.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum PixelImageError: LocalizedError {
    case readFailed
    case loadSourceFailed
    case loadImageFailed
    
    var failureReason: String? {
        switch self {
        case .readFailed:
            return "File read failed."
        case .loadSourceFailed:
            return "Load image source failed."
        case .loadImageFailed:
            return "Load image data failed."
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
        return PixelSize(pixelImageRep.size())
    }
    
    func color(at coordinate: PixelCoordinate) -> PixelColor {
        return PixelColor(id: 0, coordinate: coordinate, color: pixelImageRep.getJSTColor(of: coordinate.toCGPoint()))
    }
    
    func area(at rect: PixelRect) -> PixelArea {
        return PixelArea(id: 0, rect: rect)
    }
    
    func toNSImage() -> NSImage {
        return pixelImageRep.getNSImage()
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
