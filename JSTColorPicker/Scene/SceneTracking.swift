//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func trackCursorPositionChanged(_ sender: Any, to coordinate: PixelCoordinate)
    func trackCursorDragged(_ sender: Any, to rect: PixelRect)
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect)
    func trackSceneMagnificationChanged(_ sender: Any, to magnification: CGFloat)
}

extension SceneTracking {
    func trackCursorPositionChanged(_ sender: Any, to coordinate: PixelCoordinate) { }
    func trackCursorDragged(_ sender: Any, to rect: PixelRect) { }
    func trackCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func trackRightCursorClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func trackMagnifyToolDragged(_ sender: Any, to rect: PixelRect) { }
    func trackSceneMagnificationChanged(_ sender: Any, to magnification: CGFloat) { }
}
