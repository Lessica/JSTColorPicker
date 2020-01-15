//
//  PickerImage.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum PickerImageError: Error {
    case readFailed
    case loadSourceFailed
    case loadImageFailed
}

class PickerImage: NSObject {
    
    var imageRep: CGImage
    var imageSourceRep: CGImageSource
    var pixelImageRep: JSTPixelImage
    
    init(contentsOf url: URL) throws {
        guard let dataProvider = CGDataProvider(filename: url.path) else {
            throw PickerImageError.readFailed
        }
        guard let cgimgSource = CGImageSourceCreateWithDataProvider(dataProvider, nil) else {
            throw PickerImageError.loadSourceFailed
        }
        guard let cgimg = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw PickerImageError.loadImageFailed
        }
        
        self.imageRep = cgimg
        self.imageSourceRep = cgimgSource
        self.pixelImageRep = JSTPixelImage(cgImage: cgimg)
    }
    
}
