//
//  TabDelegate.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

protocol TabDelegate: AnyObject {
    func addManagedWindow(windowController: WindowController) -> ManagedTabWindow?
    
    @discardableResult
    func activeManagedWindow(windowController: WindowController) -> Int?
}
