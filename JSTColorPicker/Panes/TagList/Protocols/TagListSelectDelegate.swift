//
//  TagListSelectDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 6/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

protocol TagListSelectDelegate: AnyObject {
    func fetchAlternateStateForTags(_ tags: [Tag]) -> NSControl.StateValue
    func setupAlternateState(_ state: NSControl.StateValue, forTags tags: [Tag])
    func selectedState(of name: String) -> NSControl.StateValue
    func selectedStateChanged(of name: String, to state: NSControl.StateValue)
}

