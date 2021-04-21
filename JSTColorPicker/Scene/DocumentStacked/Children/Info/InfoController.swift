//
//  InfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InfoController: StackedPaneController {
    enum Style {
        case primary
        case secondary
    }
    
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-information") }

    var style                          : Style = .primary
    var imageSource                    : PixelImage.Source?
    {
        didSet {
            updateInformationPane()
        }
    }
    private var documentObservations   : [NSKeyValueObservation]?

    @IBOutlet weak var infoView        : InfoView!
    @IBOutlet weak var errorLabel      : NSTextField!

    override var isPaneStacked: Bool { true }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        if style == .primary {
            self.imageSource = screenshot.image?.imageSource

            documentObservations = [
                observe(\.screenshot?.fileURL, options: [.new]) { (target, change) in
                    if let newURL = change.newValue, let url = newURL {
                        target.updateInformationPane(alternativeURL: url)
                    } else {
                        target.updateInformationPane()
                    }
                }
            ]
        } else {
            self.imageSource = nil
            documentObservations = nil
        }
    }

    override func reloadPane() {
        super.reloadPane()
        imageSource = nil
        updateInformationPane()
        paneBox.title = style == .primary
            ? NSLocalizedString("Info (Primary)", comment: "reloadPane()")
            : NSLocalizedString("Info (Secondary)", comment: "reloadPane()")
    }
    
    private static let availableHints: [String] = [
        NSLocalizedString("Open an image of the same size for image comparison.", comment: "availableHints"),
        NSLocalizedString("Double click **Command (⌘)** to toggle command palette.", comment: "availableHints"),
    ]

    private func updateInformationPane(alternativeURL url: URL? = nil) {
        if let imageSource = imageSource {
            do {
                try infoView.setSource(imageSource, alternativeURL: url)
                errorLabel.stringValue = ""
                infoView.isHidden = false
                errorLabel.isHidden = true
            } catch {
                errorLabel.stringValue = error.localizedDescription
                infoView.isHidden = true
                errorLabel.isHidden = false
            }
        } else {
            let errorString = style == .primary
                ? NSLocalizedString("Open or drop an image here.", comment: "reloadPane()")
                : InfoController.availableHints.randomElement() ?? ""
            errorLabel.attributedStringValue = errorString.markdownAttributed
            infoView.isHidden = true
            errorLabel.isHidden = false
            infoView.reset()
        }
    }
}
