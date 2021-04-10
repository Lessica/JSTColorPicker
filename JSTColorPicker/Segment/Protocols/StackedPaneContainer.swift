//
//  StackedPaneContainer.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/10.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

protocol StackedPaneContainer: PaneContainer {
    var shouldResetDividers: Bool { get }

    func setNeedsResetDividers()
    func resetDividersIfNeeded()
    func resetDividers(in set: IndexSet?)
}
