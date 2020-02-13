//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat)
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate)
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect)
    func trackCursorDragged(_ sender: Any, to rect: PixelRect)
    func trackAreaChanged(_ sender: Any, to rect: PixelRect)
}

extension SceneTracking {
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) { }
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate) { }
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect) { }
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) { }
    func trackAreaChanged(_ sender: Any, to rect: PixelRect) { }
}
