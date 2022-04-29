//
//  TemplateOutlineView.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/16/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class TemplateOutlineView: NSOutlineView {
    
    weak var appearanceObserver: EffectiveAppearanceObserver?
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceObserver?.viewDidChangeEffectiveAppearance()
    }
    
    private static let focusLineWidth: CGFloat = 2.0
    private static let focusLineColor = NSColor.controlAccentColor
    
    @objc
    func drawContextMenuHighlightForRow(_ row: Int) {
        guard !inLiveResize else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rects = [CGRect](arrayLiteral: rect(ofRow: row))
        
        ctx.setLineWidth(TemplateOutlineView.focusLineWidth)
        ctx.setStrokeColor(TemplateOutlineView.focusLineColor.cgColor)
        
        let outerRect = bounds
            .insetBy(dx: 0.0, dy: 0.5)
            .offsetBy(dx: 0.0, dy: 0.5)
        for rect in rects.filter({ outerRect.intersects($0) }) {
            let innerRect = rect.intersection(outerRect)
            if innerRect.height > rect.height + 2.0 {
                ctx.addRect(innerRect
                                .insetBy(dx: TemplateOutlineView.focusLineWidth, dy: TemplateOutlineView.focusLineWidth + 0.5)
                                .offsetBy(dx: 0.0, dy: -0.5)
                )
            } else {
                ctx.addRect(rect
                                .insetBy(dx: TemplateOutlineView.focusLineWidth, dy: TemplateOutlineView.focusLineWidth + 0.5)
                                .offsetBy(dx: 0.0, dy: -0.5)
                )
            }
        }
        
        ctx.strokePath()
    }
    
}
