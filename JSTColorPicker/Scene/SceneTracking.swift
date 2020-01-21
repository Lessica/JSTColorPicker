//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking: class {
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool
    func mouseClicked(_ sender: Any, atPoint point: CGPoint)
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat)
}

extension SceneTracking {
    func mouseClicked(_ sender: Any, atPoint point: CGPoint) { }
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) { }
}
