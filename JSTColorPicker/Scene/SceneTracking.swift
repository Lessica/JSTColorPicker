//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func mousePositionChanged(_ sender: Any, to coordinate: PixelCoordinate)
    func mouseClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func rightMouseClicked(_ sender: Any, at coordinate: PixelCoordinate)
    func sceneMagnificationChanged(_ sender: Any, to magnification: CGFloat)
}

extension SceneTracking {
    func mousePositionChanged(_ sender: Any, to coordinate: PixelCoordinate) { }
    func mouseClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func rightMouseClicked(_ sender: Any, at coordinate: PixelCoordinate) { }
    func sceneMagnificationChanged(_ sender: Any, to magnification: CGFloat) { }
}
