//
//  SceneAnnotatorManager.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol SceneAnnotatorManager: class {
    var annotators: [SceneAnnotator] { get }
    func loadAnnotators(from content: Content) throws
    func addAnnotator(for item: PixelColor)
    func removeAnnotator(for item: PixelColor)
    func highlightAnnotator(for item: PixelColor, scrollTo: Bool)
}

