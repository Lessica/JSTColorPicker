//
//  InfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InfoController: NSViewController, PaneController {
    enum Style {
        case primary
        case secondary
    }
    
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-information")
    
    @objc dynamic weak var screenshot  : Screenshot?
    var style                          : Style = .primary
    var imageSource                    : PixelImage.Source?
    {
        didSet {
            updateInformationPane()
        }
    }
    private var documentObservations   : [NSKeyValueObservation]?

    @IBOutlet weak var paneBox         : NSBox!
    @IBOutlet weak var infoView        : InfoView!
    @IBOutlet weak var errorLabel      : NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadPane()
    }
}

extension InfoController: ScreenshotLoader {
    var isPaneHidden : Bool { view.isHiddenOrHasHiddenAncestor }
    var isPaneStacked: Bool { true }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
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

    func reloadPane() {
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
        } else {
            errorLabel.stringValue = style == .primary
                ? NSLocalizedString("Open or drop an image here.", comment: "reloadPane()")
                : NSLocalizedString("Open an image of the same size for image comparison.", comment: "reloadPane()")
            infoView.isHidden = true
            errorLabel.isHidden = false
            infoView.reset()
        }
    }
}
