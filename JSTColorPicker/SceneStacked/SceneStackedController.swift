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

class SceneStackedController: NSViewController, PaneContainer {

    @IBOutlet weak var splitView  : NSSplitView!
    var paneControllers           : [PaneController] { children.compactMap({ $0 as? PaneController }) }
    var paneContainers            : [PaneContainer]  = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.arrangedSubviews
            .forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }

    private func resetDividers(in set: IndexSet? = nil) {
        let dividerIndexes = set ?? IndexSet(integersIn: 0..<splitView.arrangedSubviews.count)
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(CGFloat.greatestFiniteMagnitude, ofDividerAt: $0) })
        }
    }

    deinit { debugPrint("\(className):\(#function)") }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let inspectorCtrl = segue.destinationController as? InspectorController {
            inspectorCtrl.style = segue.identifier == .primaryInspector ? .primary : .secondary
        }
    }

    func focusPane(menuIdentifier identifier: NSUserInterfaceItemIdentifier, completionHandler completion: @escaping (PaneContainer) -> Void) {
        let targetViews = paneControllers
            .filter({ $0.menuIdentifier == identifier })
            .map({ $0.view })

        let targetIndexSet = splitView
            .arrangedSubviews
            .enumerated()
            .filter({ obj in
                targetViews.firstIndex(where: { $0.isDescendant(of: obj.element) }) != nil
            })
            .map({ $0.offset })
            .reduce(into: IndexSet()) { $0.insert($1) }

        DispatchQueue.main.async { [unowned self] in
            completion(self)
            self.resetDividers(in: targetIndexSet)
        }
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

