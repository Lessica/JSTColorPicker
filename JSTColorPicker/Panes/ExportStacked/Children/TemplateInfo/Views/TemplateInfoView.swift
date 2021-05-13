//
//  TemplateInfoView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/3.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@IBDesignable
final class TemplateInfoView: NSView {
    private let nibName = String(describing: TemplateInfoView.self)
    private var contentView: NSView?
    
    @IBOutlet weak var templateNameStack         : NSStackView!
    @IBOutlet weak var templateVersionStack      : NSStackView!
    @IBOutlet weak var platformVersionStack      : NSStackView!
    @IBOutlet weak var authorNameStack           : NSStackView!
    @IBOutlet weak var isAsynchronousStack       : NSStackView!
    @IBOutlet weak var shouldSaveInPlaceStack    : NSStackView!
    @IBOutlet weak var templateUUIDStack         : NSStackView!
    @IBOutlet weak var templateDescriptionStack  : NSStackView!
    @IBOutlet weak var fileNameStack             : NSStackView!
    @IBOutlet weak var fileSizeStack             : NSStackView!
    @IBOutlet weak var createdAtStack            : NSStackView!
    @IBOutlet weak var modifiedAtStack           : NSStackView!
    @IBOutlet weak var fullPathStack             : NSStackView!

    @IBOutlet weak var advancedSeparator         : NSView!
    
    @IBOutlet weak var templateNameLabel         : NSTextField!
    @IBOutlet weak var templateVersionLabel      : NSTextField!
    @IBOutlet weak var platformVersionLabel      : NSTextField!
    @IBOutlet weak var authorNameLabel           : NSTextField!
    @IBOutlet weak var isAsynchronousLabel       : NSTextField!
    @IBOutlet weak var shouldSaveInPlaceLabel    : NSTextField!
    @IBOutlet weak var templateUUIDLabel         : NSTextField!
    @IBOutlet weak var templateDescriptionLabel  : NSTextField!
    @IBOutlet weak var fileNameLabel             : NSTextField!
    @IBOutlet weak var fileSizeLabel             : NSTextField!
    @IBOutlet weak var createdAtLabel            : NSTextField!
    @IBOutlet weak var modifiedAtLabel           : NSTextField!
    @IBOutlet weak var fullPathLabel             : NSTextField!

    @IBInspectable var isAdvanced                : Bool = false
    {
        didSet {
            guard let template = template else { return }
            try? setTemplate(template)
        }
    }
    
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
    
    private static var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter.init()
        return formatter
    }()

    private static var exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    private static var defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private(set) weak var template: Template?
    
    func setTemplate(_ template: Template) throws {
        self.template = template
        
        if isAdvanced {
            let attrs = try FileManager.default.attributesOfItem(atPath: template.url.path)
            
            fileNameLabel.stringValue = template.url.lastPathComponent
            fileNameStack.isHidden = false
            
            var createdAtDesc: String?
            if let createdAt = attrs[.creationDate] as? Date {
                createdAtDesc = TemplateInfoView.defaultDateFormatter.string(from: createdAt)
            }
            createdAtLabel.stringValue = createdAtDesc ?? ""
            createdAtStack.isHidden = createdAtDesc == nil
            
            var modifiedAtDesc: String?
            if let modifiedAt = attrs[.modificationDate] as? Date {
                modifiedAtDesc = TemplateInfoView.defaultDateFormatter.string(from: modifiedAt)
            }
            modifiedAtLabel.stringValue = modifiedAtDesc ?? ""
            modifiedAtStack.isHidden = modifiedAtDesc == nil
            
            let fileSize = TemplateInfoView.byteFormatter.string(fromByteCount: attrs[.size] as? Int64 ?? 0)
            fileSizeLabel.stringValue = fileSize
            fileSizeStack.isHidden = false
            
            fullPathLabel.stringValue = template.url.path
            fullPathStack.isHidden = false

            advancedSeparator.isHidden = false
        } else {
            fileNameStack.isHidden = true
            fileSizeStack.isHidden = true
            createdAtStack.isHidden = true
            modifiedAtStack.isHidden = true
            fullPathStack.isHidden = true
            advancedSeparator.isHidden = true
        }
        
        templateNameLabel.stringValue = template.name
        templateNameStack.isHidden = template.name.isEmpty
        templateVersionLabel.stringValue = template.version
        templateVersionStack.isHidden = template.version.isEmpty
        platformVersionLabel.stringValue = template.platformVersion
        platformVersionStack.isHidden = template.platformVersion.isEmpty
        authorNameLabel.stringValue = template.author ?? ""
        authorNameStack.isHidden = (template.author ?? "").isEmpty
        
        if isAdvanced {
            isAsynchronousLabel.stringValue = template.isAsync ? "Yes" : "No"
            isAsynchronousStack.isHidden = false
            shouldSaveInPlaceLabel.stringValue = template.saveInPlace ? "Yes" : "No"
            shouldSaveInPlaceStack.isHidden = false
            templateUUIDLabel.stringValue = template.uuid.uuidString
            templateUUIDStack.isHidden = false
        } else {
            isAsynchronousStack.isHidden = true
            shouldSaveInPlaceStack.isHidden = true
            templateUUIDStack.isHidden = true
        }

        templateDescriptionLabel.attributedStringValue = (template.userDescription ?? "").markdownAttributed
        templateDescriptionStack.isHidden = (template.userDescription ?? "").isEmpty
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
            fileNameLabel,
            fileSizeLabel,
            createdAtLabel,
            modifiedAtLabel,
            fullPathLabel,
        ]
        .forEach({ $0?.stringValue = "-" })
        if isAdvanced {
            [
                templateNameStack,
                templateVersionStack,
                platformVersionStack,
                authorNameStack,
                isAsynchronousStack,
                shouldSaveInPlaceStack,
                templateUUIDStack,
                templateDescriptionStack,
                fileNameStack,
                fileSizeStack,
                createdAtStack,
                modifiedAtStack,
                fullPathStack,
            ]
            .forEach({ $0?.isHidden = false })
        } else {
            [
                templateNameStack,
                templateVersionStack,
                platformVersionStack,
                authorNameStack,
                templateDescriptionStack,
            ]
            .forEach({ $0?.isHidden = false })
            [
                isAsynchronousStack,
                shouldSaveInPlaceStack,
                templateUUIDStack,
                fileNameStack,
                fileSizeStack,
                createdAtStack,
                modifiedAtStack,
                fullPathStack,
            ]
            .forEach({ $0?.isHidden = true })
        }
    }

    @IBOutlet weak var locateButton: NSButton!

    @IBAction private func locateButtonTapped(_ sender: NSButton) {
        guard let template = template else { return }
        guard template.url.isRegularFile else {
            presentError(GenericError.notRegularFile(url: template.url))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([
            template.url
        ])
    }
}
