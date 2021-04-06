//
//  SegmentController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/6.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class SegmentController: NSViewController, PaneContainer {
    @IBOutlet weak var segmentedControl  : NSSegmentedControl!
    @IBOutlet weak var tabView           : NSTabView!
    
    var paneContainers                   : [PaneContainer]   { children.compactMap({ $0 as? PaneContainer  }) }
    var paneControllers                  : [PaneController]  { children.compactMap({ $0 as? PaneController }) + paneContainers.flatMap({ $0.paneControllers }) }

    override func viewDidLoad() {
        super.viewDidLoad()
        syncSelectedStateForTabView()
    }

    @IBAction func segmentedControlValueChanged(_ sender: NSSegmentedControl) {
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
}

extension SegmentController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        invalidateRestorableState()
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
        if let identifier = coder.decodeObject(of: NSString.self, forKey: SegmentController.restorableTabViewSelectedState) as String? {
            tabView.selectTabViewItem(withIdentifier: NSUserInterfaceItemIdentifier(identifier))
            syncSelectedStateForSegmentedControl()
        }
    }
}

