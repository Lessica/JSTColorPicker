//
//  ExportStackedController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

private extension NSUserInterfaceItemIdentifier {
    static let templatesSubMenu = NSUserInterfaceItemIdentifier("TemplatesSubMenu")
}

final class ExportStackedController: StackedPaneContainer {

    @IBOutlet weak var actionView: NSView!
    @IBOutlet weak var templatePopUpButton: NSPopUpButton!
    @IBOutlet weak var templateReloadButton: NSButton!

    private let observableKeys          : [UserDefaults.Key] = [.toggleTemplateDetailedInformation]
    private var observables             : [Observable]?
            var templateInfoController  : TemplateInfoController?  { paneControllers.compactMap( { $0 as? TemplateInfoController } ).first }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatePopUpButtonWillPopUp(_:)),
            name: NSPopUpButton.willPopUpNotification,
            object: templatePopUpButton!
        )

        prepareDefaults()
        setNeedsReloadTemplates()

        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templateManagerDidLock(_:)),
            name: TemplateManager.NotificationType.Name.templateManagerDidLockNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templateManagerDidUnlock(_:)),
            name: TemplateManager.NotificationType.Name.templateManagerDidUnlockNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatesDidLoad(_:)),
            name: TemplateManager.NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectedTemplateChanged(_:)),
            name: TemplateManager.NotificationType.Name.selectedTemplateDidChangeNotification,
            object: nil
        )
    }

    private func prepareDefaults() { }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if defaultKey == .toggleTemplateDetailedInformation {
            expandStackedDividers(in: IndexSet(integer: 0), isAsync: true)
        }
    }

    override func viewWillAppear() {
        reloadTemplatesIfNeeded()
        super.viewWillAppear()
    }

    private var _shouldReloadTemplates: Bool = false
    private var shouldReloadTemplates  : Bool { _shouldReloadTemplates }

    private func setNeedsReloadTemplates() {
        _shouldReloadTemplates = true
    }

    private func reloadTemplatesIfNeeded() {
        if _shouldReloadTemplates {
            _shouldReloadTemplates = false
            reloadTemplates()
        }
    }

    private func synchronizeTitleAndSelectedItem() {
        guard let menu = templatePopUpButton.menu else { return }
        let availableItems = generateTemplatesSubMenuItems(for: menu)
        if let selectedItem = availableItems.first(where: { $0.state == .on }) {
            menu.items = availableItems
            templatePopUpButton.isEnabled = true
            templatePopUpButton.select(selectedItem)
        } else {
            templatePopUpButton.isEnabled = false
            templatePopUpButton.setTitle(NSLocalizedString("No template available.", comment: "synchronizeTitleAndSelectedItem(_:)"))
        }
    }

    private func reloadTemplates() {
        synchronizeTitleAndSelectedItem()
        templateInfoController?.template = TemplateManager.shared.selectedTemplate
    }

    private func reloadTemplatesWithNotification(_ noti: Notification) {
        synchronizeTitleAndSelectedItem()
        if let selectedTemplate = noti.userInfo?[TemplateManager.NotificationType.Key.template] as? Template
        {
            templateInfoController?.template = selectedTemplate
        }
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}

extension ExportStackedController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
    }

    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }    
}

extension ExportStackedController: NSMenuItemValidation {
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let template = menuItem.representedObject as? Template, template.isEnabled else { return false }
        
        let enabled = Template.currentPlatformVersion.isVersion(greaterThanOrEqualTo: template.platformVersion)
        
        if enabled {
            menuItem.toolTip = """
\(template.name) (\(template.version))
by \(template.author ?? "Unknown")
------
\(template.userDescription ?? "")
"""
        }
        else {
            menuItem.toolTip = Template.Error.unsatisfiedPlatformVersion(version: template.platformVersion).failureReason
        }
        
        return enabled
    }
    
    @IBAction private func templatePopUpButtonValueChanged(_ sender: NSPopUpButton) {
        guard let selectedItem = sender.selectedItem else {
            synchronizeTitleAndSelectedItem()
            templateInfoController?.template = nil
            return
        }
        guard let template = selectedItem.representedObject as? Template else {
            return
        }
        TemplateManager.shared.selectedTemplate = template
    }
    
    @IBAction private func reloadTemplatesItemTapped(_ sender: NSButton) {
        do {
            try TemplateManager.shared.reloadTemplates()
        } catch {
            presentError(error)
        }
    }
    
    private func generateTemplatesSubMenuItems(for menu: NSMenu) -> [NSMenuItem] {
        return TemplateManager.shared.templates
            .compactMap({ template -> NSMenuItem in
                
                let item = NSMenuItem(
                    title: "\(template.name) (\(template.version))",
                    action: nil,
                    keyEquivalent: ""
                )
                
                item.representedObject = template
                item.keyEquivalentModifierMask = [.control, .command]
                item.state = TemplateManager.shared.selectedTemplateUUID == template.uuid ? .on : .off
                
                return item
            })
    }
}

extension ExportStackedController {
    @objc private func templateManagerDidLock(_ noti: Notification) {
        templateReloadButton.isEnabled = false
    }

    @objc private func templateManagerDidUnlock(_ noti: Notification) {
        templateReloadButton.isEnabled = true
    }

    @objc private func templatesDidLoad(_ noti: Notification) {
        if !isViewHidden {
            reloadTemplates()
        } else {
            setNeedsReloadTemplates()
        }
        expandStackedDividers(isAsync: true)
    }
    
    @objc private func selectedTemplateChanged(_ noti: Notification) {
        reloadTemplatesWithNotification(noti)
    }
    
    @objc private func templatePopUpButtonWillPopUp(_ noti: Notification) {
        synchronizeTitleAndSelectedItem()
    }
}
