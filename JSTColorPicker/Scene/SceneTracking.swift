//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneTracking {
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat)
}

extension SceneTracking {
    func mousePositionChanged(_ sender: Any, toPoint point: CGPoint) -> Bool { return false }
    func sceneMagnificationChanged(_ sender: Any, toMagnification magnification: CGFloat) { }
}
