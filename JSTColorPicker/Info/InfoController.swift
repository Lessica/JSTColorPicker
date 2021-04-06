//
//  InfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InfoController: NSViewController, PaneController {
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-information")
    
    @objc dynamic weak var screenshot            : Screenshot?
    private var documentObservations             : [NSKeyValueObservation]?

    private var imageSource                      : PixelImage.Source? { screenshot?.image?.imageSource }
    private var altImageSource                   : PixelImage.Source?
    private var exitComparisonHandler            : ((Bool) -> Void)?

    @IBOutlet weak var paneBox                   : NSBox!
    @IBOutlet weak var infoView1                 : InfoView!
    @IBOutlet weak var errorLabel1               : NSTextField!
    @IBOutlet weak var infoView2                 : InfoView!
    @IBOutlet weak var errorLabel2               : NSTextField!
    @IBOutlet weak var imageActionView           : NSView!
    @IBOutlet weak var exitComparisonModeButton  : NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        updateInformationPanel()
    }

    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
}

extension InfoController: ScreenshotLoader {
    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }
    var isPaneStacked: Bool { false }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        self.altImageSource = nil

        reloadPane()
        documentObservations = [
            observe(\.screenshot?.fileURL, options: [.new]) { [unowned self] (_, change) in
                self.updateInformationPanel()
            }
        ]
    }

    func reloadPane() {
        updateInformationPanel()
    }

    private func updateInformationPanel() {
        
        if let imageSource = imageSource {
            do {
                try infoView1.setSource(imageSource)
                infoView1.isHidden = false
                errorLabel1.isHidden = true
            } catch {
                errorLabel1.stringValue = error.localizedDescription
                infoView1.isHidden = true
                errorLabel1.isHidden = false
            }
        } else {
            errorLabel1.stringValue = NSLocalizedString("Open or drop an image here.", comment: "updateInformationPanel()")
            infoView1.isHidden = true
            errorLabel1.isHidden = false
            infoView1.reset()
        }
        
        if let imageSource = altImageSource {
            do {
                try infoView2.setSource(imageSource)
                infoView2.isHidden = false
                errorLabel2.isHidden = true
            } catch {
                errorLabel2.stringValue = error.localizedDescription
                infoView2.isHidden = true
                errorLabel2.isHidden = false
            }
            imageActionView.isHidden = false
        } else {
            infoView2.isHidden = true
            errorLabel2.isHidden = true
            imageActionView.isHidden = true
            infoView2.reset()
        }
    }
}

extension InfoController: PixelMatchResponder {
    @IBAction func exitComparisonModeButtonTapped(_ sender: NSButton) {
        if let exitComparisonHandler = exitComparisonHandler {
            exitComparisonHandler(true)
        }
    }

    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        altImageSource = image.imageSource
        exitComparisonHandler = completionHandler
        updateInformationPanel()
    }

    func endPixelMatchComparison() {
        altImageSource = nil
        exitComparisonHandler = nil
        updateInformationPanel()
    }

    private var isInComparisonMode: Bool {
        return imageSource != nil && altImageSource != nil
    }
}
