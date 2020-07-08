//
//  SceneTracking.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


protocol SceneTracking: class {
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat)
    func sceneRawColorDidChange   (_ sender: SceneScrollView?, at coordinate: PixelCoordinate)
    func sceneRawAreaDidChange    (_ sender: SceneScrollView?, to rect: PixelRect)
    func sceneWillStartLiveResize (_ sender: SceneScrollView?)
    func sceneDidEndLiveResize    (_ sender: SceneScrollView?)
}

extension SceneTracking {
    func sceneVisibleRectDidChange(_ sender: SceneScrollView?, to rect: CGRect, of magnification: CGFloat) { }
    func sceneRawColorDidChange   (_ sender: SceneScrollView?, at coordinate: PixelCoordinate)             { }
    func sceneRawAreaDidChange    (_ sender: SceneScrollView?, to rect: PixelRect)                         { }
    func sceneWillStartLiveResize (_ sender: SceneScrollView?)                                             { }
    func sceneDidEndLiveResize    (_ sender: SceneScrollView?)                                             { }
}

