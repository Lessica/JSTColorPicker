//
//  SceneStackedController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

private extension NSStoryboardSegue.Identifier {
    static let primaryInspector = "PrimaryInspector"
    static let secondaryInspector = "SecondaryInspector"
    static let preview = "Preview"
}

class SceneStackedController: StackedPaneContainer {
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let inspectorCtrl = segue.destinationController as? InspectorController {
            inspectorCtrl.style = segue.identifier == .primaryInspector ? .primary : .secondary
        }
    }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        expandStackedDividers(isAsync: true)
    }
}

extension SceneStackedController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
    }
    
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }
}

