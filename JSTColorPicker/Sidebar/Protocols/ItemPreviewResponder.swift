//
//  ItemPreviewResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/7/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ItemPreviewResponder: class {
    func previewAction(_ sender: Any?, centeredAt coordinate: PixelCoordinate)
    func previewAction(_ sender: Any?, toMagnification magnification: CGFloat, isChanging: Bool)
}
