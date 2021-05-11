//
//  SegmentController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class SegmentController: NSViewController {
    weak var screenshot: Screenshot?
    
    @IBOutlet weak var segmentedControl  : NSSegmentedControl!
    @IBOutlet weak var tabView           : NSTabView!

    override func viewDidLoad() {
        super.viewDidLoad()
        if segmentedControl.selectedSegment < 0 {
            segmentedControl.selectedSegment = 0
        }
        syncSelectedStateForTabView()
    }

    deinit {
        debugPrint("\(className):\(#function)")
    }

    @IBAction private func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
        syncSelectedStateForTabView()
    }

    private func syncSelectedStateForTabView() {
        guard segmentedControl.selectedSegment >= 0 else { return }
        tabView.selectTabViewItem(at: segmentedControl.selectedSegment)
    }

    private func syncSelectedStateForSegmentedControl() {
        guard let selectedItem = tabView.selectedTabViewItem else { return }
        let selectedIndex = tabView.indexOfTabViewItem(selectedItem)
        segmentedControl.selectedSegment = selectedIndex
    }

    private func selectTabViewItem(_ tabViewItem: NSTabViewItem?) {
        tabView.selectTabViewItem(tabViewItem)
        syncSelectedStateForSegmentedControl()
    }

    private func selectTabViewItem(withIdentifier identifier: NSUserInterfaceItemIdentifier) {
        tabView.selectTabViewItem(withIdentifier: identifier)
        syncSelectedStateForSegmentedControl()
    }
}

extension SegmentController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        invalidateRestorableState()
    }
}

extension SegmentController: PaneContainer {
    var childPaneContainers      : [PaneContainer]          { children.compactMap(  { $0 as? PaneContainer  }  ) }
    var paneControllers          : [PaneController]         { children.compactMap(  { $0 as? PaneController }  ) }
    
    private var stackedChildPaneContainers : [StackedPaneContainer]
    {
        childPaneContainers.compactMap({ $0 as? StackedPaneContainer })
    }
    
    private var descendantPaneContainers   : [PaneContainer]
    {
        var childContainers = [NSViewController]()
        var allContainers = [NSViewController](arrayLiteral: self)
        while let lastContainer = allContainers.popLast() {
            childContainers.append(lastContainer)
            allContainers.insert(contentsOf: lastContainer.children.compactMap({ $0 as? PaneContainer }) as! [NSViewController], at: 0)
        }
        return Array(childContainers.dropFirst()) as! [PaneContainer]
    }
    
    private var descendantPaneControllers  : [PaneController]
    {
        paneControllers + descendantPaneContainers.flatMap({ $0.paneControllers })
    }
    
    func focusPane(menuIdentifier identifier: NSUserInterfaceItemIdentifier, completionHandler completion: @escaping (PaneContainer) -> Void) {
        let handler = { [unowned self] (sender: PaneContainer) in
            if let targetView = self.descendantPaneControllers.first(where: { $0.menuIdentifier == identifier })?.view {
                if let targetItem = self.tabView.tabViewItems
                    .filter({ $0.view != nil })
                    .first(where: { targetView.isDescendant(of: $0.view!) })
                {
                    self.selectTabViewItem(targetItem)
                }
            }
            completion(sender)
        }
        childPaneContainers.forEach(
            { $0.focusPane(menuIdentifier: identifier, completionHandler: handler) }
        )
    }
}

extension SegmentController: ScreenshotLoader {
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
    }
}

extension SegmentController {
    private static let restorableTabViewSelectedState = "tabView.selectedTabViewItem"

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if let selectedItem = tabView.selectedTabViewItem,
           let selectedIdentifier = selectedItem.identifier as? NSUserInterfaceItemIdentifier
        {
            coder.encode(selectedIdentifier.rawValue, forKey: SegmentController.restorableTabViewSelectedState)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let identifier = coder.decodeObject(of: NSString.self, forKey: SegmentController.restorableTabViewSelectedState) as String?
        {
            stackedChildPaneContainers.forEach({ $0.setNeedsResetDividers() })
            selectTabViewItem(withIdentifier: NSUserInterfaceItemIdentifier(identifier))
        }
    }
}

