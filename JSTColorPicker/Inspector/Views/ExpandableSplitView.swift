//
//  ExpandableSplitView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/3/17.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class ExpandableSplitView: NSSplitView {

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 && arrangedSubviews.count == 2 {
            let locationInView = convert(event.locationInWindow, from: nil)
            if let dividerIndex = arrangedSubviews.firstIndex(where: { $0.frame.contains(locationInView) }), dividerIndex < arrangedSubviews.count {
                setPosition(dividerIndex == 0 ? maxPossiblePositionOfDivider(at: 0) : minPossiblePositionOfDivider(at: 0), ofDividerAt: 0)
                return
            }
        }
        super.mouseUp(with: event)
    }

}
