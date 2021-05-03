//
//  ToolbarResponder.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

@objc protocol ToolbarResponder {
    @objc optional func openAction(_ sender: Any?)
    func useAnnotateItemAction(_ sender: Any?)
    func useMagnifyItemAction(_ sender: Any?)
    func useMinifyItemAction(_ sender: Any?)
    func useSelectItemAction(_ sender: Any?)
    func useMoveItemAction(_ sender: Any?)
    func fitWindowAction(_ sender: Any?)
    func fillWindowAction(_ sender: Any?)
    func zoomInAction(_ sender: Any?)
    func zoomOutAction(_ sender: Any?)
    func zoomToAction(_ sender: Any?, value: Double)
}
