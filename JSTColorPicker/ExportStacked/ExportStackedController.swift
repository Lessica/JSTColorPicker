//
//  ExportStackedController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ExportStackedController: NSViewController {
    weak var screenshot: Screenshot?
    
    @IBOutlet weak var actionView: NSView!
    @IBOutlet weak var templatePopUpButton: NSPopUpButton!
    @IBOutlet weak var splitView: NSSplitView!

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.arrangedSubviews
            .forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
        
        setNeedsResetDividers()
    }
    
    private var isViewHidden: Bool = true

    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        resetDividersIfNeeded()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }

    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }

    private var _shouldResetDividers: Bool = false

    deinit { debugPrint("\(className):\(#function)") }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) { }
}

extension ExportStackedController: StackedPaneContainer {
    
    var shouldResetDividers: Bool { _shouldResetDividers }
    
    func setNeedsResetDividers() {
        _shouldResetDividers = true
    }

    func resetDividersIfNeeded() {
        if _shouldResetDividers {
            _shouldResetDividers = false
            resetDividers()
        }
    }

    func resetDividers(in set: IndexSet? = nil) {
        let dividerIndexes = set ?? IndexSet(integersIn: 0..<splitView.arrangedSubviews.count)
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(CGFloat.greatestFiniteMagnitude, ofDividerAt: $0) })
        }
    }
    
}

extension ExportStackedController: PaneContainer {
    var childPaneContainers      : [PaneContainer]          { children.compactMap(  { $0 as? PaneContainer  }  ) }
    var paneControllers          : [PaneController]         { children.compactMap(  { $0 as? PaneController }  ) }
    
    var templateInfoController   : TemplateInfoController?  { paneControllers.compactMap( { $0 as? TemplateInfoController } ).first }

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

extension ExportStackedController: ScreenshotLoader {
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        updateStackedChildren(isAsync: true)
    }
}

extension ExportStackedController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
    }

    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }
}

extension ExportStackedController {
    private func updateStackedChildren(isAsync async: Bool) {
        // TODO: update
        guard !isViewHidden else {
            setNeedsResetDividers()
            return
        }
        if async {
            DispatchQueue.main.async { [unowned self] in
                self.resetDividers()
            }
        } else {
            self.resetDividers()
        }
    }
    
    @IBAction func templatePopUpButtonValueChanged(_ sender: NSPopUpButton) {
        
    }
}
