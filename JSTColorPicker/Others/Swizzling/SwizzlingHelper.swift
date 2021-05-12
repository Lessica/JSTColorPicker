//
//  SwizzlingHelper.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/2.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class SwizzlingHelper {
    private static let doOnce: Any? = {
        NSView.inject()
        return nil
    }()

    static func enableInjection() {
        _ = SwizzlingHelper.doOnce
    }
}
