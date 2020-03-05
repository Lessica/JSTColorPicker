//
//  AnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class AnnotatorOverlay: EditableOverlay {
    
    public static let defaultOffset = CGPoint(x: -16.0, y: -16.0)
    public static let defaultSize = CGSize(width: 32.0, height: 32.0)
    
    public var isSmallOverlay: Bool = true
    public var isHighlighted: Bool = true
    fileprivate var internalLabel: String
    public var label: String {
        return internalLabel
    }
    override var isBordered: Bool {
        return !isSmallOverlay
    }
    
    init(label: String) {
        self.internalLabel = label
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard isSmallOverlay else {
            super.draw(dirtyRect)
            return
        }
    }
    
}
