//
//  ExportStackedView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ExportStackedView: StackedView {
    override var adjustingDividersAutomatically: Bool { true }

    var customDividerColor: CGColor {
        if NSAppearance.current.isLight {
            return .init(gray: 0.0, alpha: 0.098039)
        } else {
            return .init(gray: 1.0, alpha: 0.137255)
        }
    }

    override func drawDivider(in rect: NSRect) {
        guard !inLiveResize else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(customDividerColor)
        ctx.fill(rect)
    }
}
