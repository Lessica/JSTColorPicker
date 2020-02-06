//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func trackColorChanged(_ sender: Any, at coordinate: PixelCoordinate)
    func trackAreaChanged(_ sender: Any, to rect: PixelRect)
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func trackCursorDragged(_ sender: Any, to rect: PixelRect)
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect)
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat)
}

extension SceneTracking {
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) { }
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect) { }
    func trackSceneBoundsChanged(_ sender: Any, to rect: CGRect, of magnification: CGFloat) { }
}
