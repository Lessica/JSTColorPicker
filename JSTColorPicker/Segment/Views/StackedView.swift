//
//  StackedView.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/15/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class StackedView: NSSplitView {
    private var hasAttachedSheet: Bool { window?.attachedSheet != nil }
    override func menu(for event: NSEvent) -> NSMenu? {
        guard !hasAttachedSheet else { return nil }
        return super.menu(for: event)
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            let locationInView = convert(event.locationInWindow, from: nil)
            if let dividerIndex = arrangedSubviews.firstIndex(where: { $0.frame.contains(locationInView) }), dividerIndex < arrangedSubviews.count {
                setPosition(CGFloat.greatestFiniteMagnitude, ofDividerAt: dividerIndex)
                return
            }
        }
        super.mouseUp(with: event)
    }

    override var dividerColor: NSColor {
        if NSAppearance.current.isLight {
            return super.dividerColor
        } else {
            return NSColor.secondaryLabelColor.withAlphaComponent(0.24)
        }
    }
}