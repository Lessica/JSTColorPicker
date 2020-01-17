//
//  PixelImage.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum PixelImageError: Error {
    case readFailed
    case loadSourceFailed
    case loadImageFailed
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
        guard let cgimgSource = CGImageSourceCreateWithDataProvider(dataProvider, nil) else {
            throw PixelImageError.loadSourceFailed
        }
        guard let cgimg = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw PixelImageError.loadImageFailed
        }
        
        self.imageURL = url
        self.imageRep = cgimg
        self.imageSourceRep = cgimgSource
        self.pixelImageRep = JSTPixelImage(cgImage: cgimg)
    }
    
    deinit {
        debugPrint("- [PixelImage deinit]")
    }
    
}
