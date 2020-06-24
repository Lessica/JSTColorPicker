//
//  ItemPreviewDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ItemPreviewDelegate: class {
    func updatePreview(to rect: CGRect, magnification: CGFloat)
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?)
}
