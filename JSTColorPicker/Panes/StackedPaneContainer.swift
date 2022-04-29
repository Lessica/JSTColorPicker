//
//  StackedPaneContainer.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/10.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class StackedPaneContainer: NSViewController, PaneContainer {
              weak var screenshot  : Screenshot?
    @IBOutlet weak var splitView   : StackedView!

    var isViewHidden: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.arrangedSubviews
            .forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
        expandStackedDividers(isAsync: false)
    }

    deinit {
        debugPrint("\(className):\(#function)")
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        resetDividersIfNeeded()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }

    // MARK: - Dividers

    private var _shouldResetDividerIndices: IndexSet?
    var shouldResetDividers    : Bool { _shouldResetDividerIndices != nil }

    func setNeedsResetDividers() {
        _shouldResetDividerIndices = IndexSet(integersIn: 0..<splitView.arrangedSubviews.count)
    }

    func setNeedsResetDividers(in set: IndexSet) {
        _shouldResetDividerIndices = set
    }

    func resetDividersIfNeeded() {
        if shouldResetDividers {
            resetDividers(in: _shouldResetDividerIndices)
            _shouldResetDividerIndices = nil
        }
    }

    func resetDividers(in set: IndexSet? = nil) {
        let dividerIndexes = set ?? IndexSet(integersIn: 0..<splitView.arrangedSubviews.count)
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(CGFloat.greatestFiniteMagnitude, ofDividerAt: $0) })
        }
    }

    // MARK: - Pane Focus

    var childPaneContainers      : [PaneContainer]          { children.compactMap(  { $0 as? PaneContainer  }  ) }
    var paneControllers          : [PaneController]         { children.compactMap(  { $0 as? PaneController }  ) }

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

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            completion(self)
            self.resetDividers(in: targetIndexSet)
        }
    }

    func expandStackedDividers(in set: IndexSet? = nil, isAsync async: Bool) {
        guard !isViewHidden else {
            if let set = set {
                setNeedsResetDividers(in: set)
            } else {
                setNeedsResetDividers()
            }
            return
        }
        if async {
            DispatchQueue.main.async { [weak self] in
                self?.resetDividers(in: set)
            }
        } else {
            self.resetDividers(in: set)
        }
    }

    // MARK: - Screenshot Loader

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        // DO NOT MODIFY THIS METHOD
    }
}
