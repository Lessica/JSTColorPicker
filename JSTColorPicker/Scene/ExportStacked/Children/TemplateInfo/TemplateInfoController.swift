//
//  TemplateInfoController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class TemplateInfoController: StackedPaneController {
    override var menuIdentifier: NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-template-information") }

    private let observableKeys        : [UserDefaults.Key] = [.toggleTemplateDetailedInformation]
    private var observables           : [Observable]?
    weak    var template              : Template?
    {
        didSet {
            updateTemplatePane()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        prepareDefaults()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
    }

    private func prepareDefaults() {
        let advancedVal: Bool = UserDefaults.standard[.toggleTemplateDetailedInformation]
        let advancedValState: NSControl.StateValue = advancedVal ? .on : .off
        detailButton.state = advancedValState
        templateInfoView.isAdvanced = advancedVal
    }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .toggleTemplateDetailedInformation, let toValue = defaultValue as? Bool {
            let advancedValState: NSControl.StateValue = toValue ? .on : .off
            if detailButton.state != advancedValState {
                detailButton.state = advancedValState
            }
            if templateInfoView.isAdvanced != toValue {
                templateInfoView.isAdvanced = toValue
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        displayTemplateIfNeeded()
    }

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

    @IBAction func detailButtonTapped(_ sender: NSButton) {
        templateInfoView.isAdvanced = sender.state == .on
        UserDefaults.standard[.toggleTemplateDetailedInformation] = sender.state == .on
    }

    override var isPaneStacked: Bool { true }

    override func reloadPane() {
        super.reloadPane()
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
