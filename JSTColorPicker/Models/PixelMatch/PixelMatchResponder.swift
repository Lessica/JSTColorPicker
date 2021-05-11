//
//  PixelMatchResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/14/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol PixelMatchResponder: CustomResponder {
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (_ shouldExit: Bool) -> Void)
    func endPixelMatchComparison()
}
