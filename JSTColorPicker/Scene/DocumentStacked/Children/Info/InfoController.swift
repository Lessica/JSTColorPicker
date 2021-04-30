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
    @IBOutlet weak var nextButton      : NSButton!

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
            nextButton.isHidden = true
        } else {
            let errorString = style == .primary
                ? NSLocalizedString("Open or drop an image here.", comment: "reloadPane()")
                : nextHint()
            errorLabel.attributedStringValue = errorString.markdownAttributed
            infoView.isHidden = true
            errorLabel.isHidden = false
            nextButton.isHidden = style != .secondary
            infoView.reset()
        }
    }
    
    @IBAction func shuffleButtonTapped(_ sender: NSButton) {
        guard style == .secondary && imageSource == nil else { return }
        errorLabel.attributedStringValue = nextHint().markdownAttributed
    }
    
    private var currentHintIndex: Int?
    
    private static let availableHints: [String] = [
        NSLocalizedString("Open an image of the same size for image comparison.", comment: "availableHints"),
        NSLocalizedString("Double click **Command (⌘)** to toggle command palette.", comment: "availableHints"),
        NSLocalizedString("Right click and drag to move the scene.", comment: "availableHints"),
        NSLocalizedString("Use your physical scroll wheel to scale the scene.", comment: "availableHints")
    ]
    
    private func nextHint() -> String {
        let availableHints = InfoController.availableHints
        guard availableHints.count > 0 else {
            fatalError("availableHints is empty")
        }
        var nextIndex = currentHintIndex ?? (availableHints.startIndex..<availableHints.endIndex).randomElement()!
        if nextIndex == availableHints.endIndex - 1 {
            nextIndex = availableHints.startIndex
        } else {
            nextIndex += 1
        }
        let currentHint = availableHints[nextIndex]
        currentHintIndex = nextIndex
        return currentHint
    }
    
}
