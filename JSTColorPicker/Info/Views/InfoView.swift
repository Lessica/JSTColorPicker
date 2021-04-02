//
//  InfoView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/3.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InfoView: NSView {
    let nibName = "InfoView"
    var contentView: NSView?
    
    @IBOutlet weak var fileNameStack: NSStackView!
    @IBOutlet weak var fileSizeStack: NSStackView!
    @IBOutlet weak var createdAtStack: NSStackView!
    @IBOutlet weak var modifiedAtStack: NSStackView!
    @IBOutlet weak var snapshotAtStack: NSStackView!
    @IBOutlet weak var dimensionStack: NSStackView!
    @IBOutlet weak var colorSpaceStack: NSStackView!
    @IBOutlet weak var colorProfileStack: NSStackView!
    @IBOutlet weak var fullPathStack: NSStackView!
    
    @IBOutlet weak var fileNameLabel: NSTextField!
    @IBOutlet weak var fileSizeLabel: NSTextField!
    @IBOutlet weak var createdAtLabel: NSTextField!
    @IBOutlet weak var modifiedAtLabel: NSTextField!
    @IBOutlet weak var snapshotAtLabel: NSTextField!
    @IBOutlet weak var dimensionLabel: NSTextField!
    @IBOutlet weak var colorSpaceLabel: NSTextField!
    @IBOutlet weak var colorProfileLabel: NSTextField!
    @IBOutlet weak var fullPathLabel: NSTextField!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        guard let view = loadViewFromNib() else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        contentView = view
    }
    
    func loadViewFromNib() -> NSView? {
        var views: NSArray?
        guard NSNib(nibNamed: nibName, bundle: Bundle(for: type(of: self)))!.instantiate(withOwner: self, topLevelObjects: &views)
        else { return nil }
        return views?.compactMap({ $0 as? NSView }).first
    }
}
