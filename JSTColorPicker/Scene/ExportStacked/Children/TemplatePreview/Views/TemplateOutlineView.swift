//
//  TemplateOutlineView.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/16/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class TemplateOutlineView: NSOutlineView {
    
    weak var appearanceObserver: EffectiveAppearanceObserver?
    
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceObserver?.viewDidChangeEffectiveAppearance()
    }
    
}
