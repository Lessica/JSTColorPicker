//
//  TagListEditDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListEditDelegate: class {
    var alternateState: NSControl.StateValue { get set }
    func editState(of name: String) -> NSControl.StateValue
    func editStateChanged(of name: String, to state: NSControl.StateValue)
}

