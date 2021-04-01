//
//  ItemPreviewDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ItemPreviewDelegate: SceneTracking {
    func ensureOverlayBounds(to rect: CGRect?, magnification: CGFloat?)
    func updatePreview(to rect: CGRect, magnification: CGFloat)
}
