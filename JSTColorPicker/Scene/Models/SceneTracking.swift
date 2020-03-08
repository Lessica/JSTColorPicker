//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat)
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate)
    func trackAreaChanged(_ sender: SceneScrollView?, to rect: PixelRect)
    func trackMagnifyingGlassDragged(_ sender: SceneScrollView?, to rect: PixelRect)
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to rect: PixelRect)
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to coordinate: PixelCoordinate)
}

extension SceneTracking {
    func trackSceneBoundsChanged(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) { }
    func trackColorChanged(_ sender: SceneScrollView?, at coordinate: PixelCoordinate) { }
    func trackAreaChanged(_ sender: SceneScrollView?, to rect: PixelRect) { }
    func trackMagnifyingGlassDragged(_ sender: SceneScrollView?, to rect: PixelRect) { }
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to rect: PixelRect) { }
    func trackMagicCursorDragged(_ sender: SceneScrollView?, to coordinate: PixelCoordinate) { }
}
