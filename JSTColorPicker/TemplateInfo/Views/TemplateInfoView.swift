//
//  TemplateInfoView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/3.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@IBDesignable
class TemplateInfoView: NSView {
    private let nibName = String(describing: TemplateInfoView.self)
    private var contentView: NSView?
    
    @IBOutlet weak var templateNameStack: NSStackView!
    @IBOutlet weak var templateVersionStack: NSStackView!
    @IBOutlet weak var platformVersionStack: NSStackView!
    @IBOutlet weak var authorNameStack: NSStackView!
    @IBOutlet weak var isAsynchronousStack: NSStackView!
    @IBOutlet weak var shouldSaveInPlaceStack: NSStackView!
    @IBOutlet weak var templateUUIDStack: NSStackView!
    @IBOutlet weak var templateDescriptionStack: NSStackView!
    
    @IBOutlet weak var templateNameLabel: NSTextField!
    @IBOutlet weak var templateVersionLabel: NSTextField!
    @IBOutlet weak var platformVersionLabel: NSTextField!
    @IBOutlet weak var authorNameLabel: NSTextField!
    @IBOutlet weak var isAsynchronousLabel: NSTextField!
    @IBOutlet weak var shouldSaveInPlaceLabel: NSTextField!
    @IBOutlet weak var templateUUIDLabel: NSTextField!
    @IBOutlet weak var templateDescriptionLabel: NSTextField!
    
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
    
    func setTemplate(_ template: Template) {
        templateNameLabel.stringValue = template.name
        templateNameStack.isHidden = template.name.isEmpty
        templateVersionLabel.stringValue = template.version
        templateVersionStack.isHidden = template.version.isEmpty
        platformVersionLabel.stringValue = template.platformVersion
        platformVersionStack.isHidden = template.platformVersion.isEmpty
        authorNameLabel.stringValue = template.author ?? ""
        authorNameStack.isHidden = (template.author ?? "").isEmpty
        isAsynchronousLabel.stringValue = template.isAsync ? "Yes" : "No"
        isAsynchronousStack.isHidden = false
        shouldSaveInPlaceLabel.stringValue = template.saveInPlace ? "Yes" : "No"
        shouldSaveInPlaceStack.isHidden = false
        templateUUIDLabel.stringValue = template.uuid.uuidString
        templateUUIDStack.isHidden = false
        templateDescriptionLabel.stringValue = template.description ?? ""
        templateDescriptionStack.isHidden = (template.description ?? "").isEmpty
    }
    
    func reset() {
        [
            templateNameLabel,
            templateVersionLabel,
            platformVersionLabel,
            authorNameLabel,
            isAsynchronousLabel,
            shouldSaveInPlaceLabel,
            templateUUIDLabel,
            templateDescriptionLabel,
        ]
        .forEach({ $0?.stringValue = "" })
        [
            templateNameStack,
            templateVersionStack,
            platformVersionStack,
            authorNameStack,
            isAsynchronousStack,
            shouldSaveInPlaceStack,
            templateUUIDStack,
            templateDescriptionStack,
        ]
        .forEach({ $0?.isHidden = true })
    }
}
