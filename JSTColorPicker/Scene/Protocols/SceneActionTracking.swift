//
//  SceneActionTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 7/8/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol SceneActionTracking: SceneTracking {
    func sceneMagnifyingGlassActionDidEnd(_ sender: SceneScrollView?, to rect: PixelRect)
    func sceneMagicCursorActionDidEnd    (_ sender: SceneScrollView?, to rect: PixelRect)
    func sceneMagicCursorActionDidEnd    (_ sender: SceneScrollView?, to coordinate: PixelCoordinate)
    func sceneMovingHandActionWillBegin  (_ sender: SceneScrollView?)
    func sceneMovingHandActionDidEnd     (_ sender: SceneScrollView?)
}

