//
//  RulerViewClient.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol RulerViewClient: class {
    func rulerView(_ ruler: RulerView?, shouldAdd marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, shouldMove marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, shouldRemove marker: RulerMarker) -> Bool
    func rulerView(_ ruler: RulerView?, didAdd marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, didMove marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, didRemove marker: RulerMarker)
    func rulerView(_ ruler: RulerView?, willMove marker: RulerMarker, toLocation location: Int) -> Int
}

