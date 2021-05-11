//
//  PaneContainer.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

protocol PaneContainer: ScreenshotLoader {
    var paneControllers: [PaneController] { get }
    var childPaneContainers: [PaneContainer] { get }

    func focusPane(
        menuIdentifier identifier: NSUserInterfaceItemIdentifier,
        completionHandler completion: @escaping (PaneContainer) -> Void
    )
}
