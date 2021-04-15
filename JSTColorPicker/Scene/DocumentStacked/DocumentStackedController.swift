//
//  DocumentStackedController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

private extension NSStoryboardSegue.Identifier {
    static let primaryInfo = "PrimaryInfo"
    static let secondaryInfo = "SecondaryInfo"
}

class DocumentStackedController: StackedPaneContainer {

    @IBOutlet weak var actionView: NSView!
    private var exitComparisonHandler: ((Bool) -> Void)?

    var primaryInfoController    : InfoController?   { paneControllers.compactMap( { $0 as? InfoController } ).first(where: { $0.style == .primary   }) }
    var secondaryInfoController  : InfoController?   { paneControllers.compactMap( { $0 as? InfoController } ).first(where: { $0.style == .secondary }) }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let inspectorCtrl = segue.destinationController as? InfoController {
            inspectorCtrl.style = segue.identifier == .primaryInfo ? .primary : .secondary
        }
    }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        expandStackedDividers(isAsync: true)
    }

    override func expandStackedDividers(in set: IndexSet? = nil, isAsync async: Bool) {
        actionView.isHidden = !isInComparisonMode
        super.expandStackedDividers(in: set, isAsync: async)
    }
}

extension DocumentStackedController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
    }

    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }
}

extension DocumentStackedController: PixelMatchResponder {

    @IBAction func exitComparisonModeButtonTapped(_ sender: NSButton) {
        if let exitComparisonHandler = exitComparisonHandler {
            exitComparisonHandler(true)
        }
    }

    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        exitComparisonHandler = completionHandler
        secondaryInfoController?.imageSource = image.imageSource
        setNeedsResetDividers()
        expandStackedDividers(isAsync: false)
    }

    func endPixelMatchComparison() {
        secondaryInfoController?.reloadPane()
        exitComparisonHandler = nil
        setNeedsResetDividers()
        expandStackedDividers(isAsync: false)
    }

    private var isInComparisonMode: Bool {
        return primaryInfoController?.imageSource != nil && secondaryInfoController?.imageSource != nil
    }
}
