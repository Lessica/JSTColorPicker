//
//  PaneContainer.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

protocol PaneContainer {
    var paneControllers: [PaneController] { get }
    var paneContainers: [PaneContainer] { get }

    func focusPane(
        menuIdentifier identifier: NSUserInterfaceItemIdentifier,
        completionHandler completion: @escaping (PaneContainer) -> Void
    )
}
