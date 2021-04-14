//
//  TemplateInfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class TemplateInfoController: NSViewController, PaneController {
    var menuIdentifier = NSUserInterfaceItemIdentifier("show-template-information")
    
    weak var screenshot  : Screenshot?
    weak var template    : Template?
    {
        didSet {
            updateTemplatePane()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyPreferences(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    private var isViewHidden: Bool = true
    
    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        displayTemplateIfNeeded()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBOutlet weak var paneBox           : NSBox!
    @IBOutlet weak var errorLabel        : NSTextField!
    @IBOutlet weak var templateInfoView  : TemplateInfoView!
    @IBOutlet weak var detailButton      : NSButton!
    
    private var _shouldDisplayTemplate: Bool = false
    var shouldDisplayTemplate: Bool { _shouldDisplayTemplate }
    
    private func setNeedsDisplayTemplate() {
        _shouldDisplayTemplate = true
    }
    
    private func displayTemplateIfNeeded() {
        if _shouldDisplayTemplate {
            _shouldDisplayTemplate = false
            updateTemplatePane()
        }
    }

    @objc private func applyPreferences(_ notification: Notification?) {
        let advancedVal: Bool = UserDefaults.standard[.toggleTemplateDetailedInformation]
        let advancedValState: NSControl.StateValue = advancedVal ? .on : .off
        if detailButton.state != advancedValState {
            detailButton.state = advancedValState
        }
        if templateInfoView.isAdvanced != advancedVal {
            templateInfoView.isAdvanced = advancedVal
        }
    }

    @IBAction func detailButtonTapped(_ sender: NSButton) {
        templateInfoView.isAdvanced = sender.state == .on
        UserDefaults.standard[.toggleTemplateDetailedInformation] = sender.state == .on
    }
}

extension TemplateInfoController: ScreenshotLoader {
    var isPaneHidden : Bool { view.isHiddenOrHasHiddenAncestor || isViewHidden }
    var isPaneStacked: Bool { true }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        // DO NOT MODIFY THIS METHOD
    }

    func reloadPane() {
        template = nil
        updateTemplatePane()
    }

    private func updateTemplatePane() {
        guard !isPaneHidden else {
            setNeedsDisplayTemplate()
            return
        }
        if let template = template {
            do {
                try templateInfoView.setTemplate(template)
                templateInfoView.isHidden = false
                errorLabel.stringValue = ""
                errorLabel.isHidden = true
            } catch {
                templateInfoView.isHidden = true
                errorLabel.stringValue = error.localizedDescription
                errorLabel.isHidden = false
            }
        } else {
            templateInfoView.isHidden = true
            errorLabel.stringValue = NSLocalizedString("No template selected.", comment: "updateTemplate(_:)")
            errorLabel.isHidden = false
        }
    }
}
