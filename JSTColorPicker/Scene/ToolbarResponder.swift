//
//  ToolbarResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol ToolbarResponder {
    func useCursorAction(_ sender: Any?)
    func useMagnifyToolAction(_ sender: Any?)
    func useMinifyToolAction(_ sender: Any?)
}
