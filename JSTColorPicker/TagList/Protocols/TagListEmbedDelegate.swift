//
//  TagListEmbedDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListEmbedDelegate: class {
    func embedState(of name: String) -> NSControl.StateValue
    func embedStateChanged(of name: String, to state: NSControl.StateValue)
}

