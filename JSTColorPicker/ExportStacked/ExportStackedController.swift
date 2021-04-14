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

class ExportStackedController: NSViewController {
    weak var screenshot: Screenshot?
    
    @IBOutlet weak var actionView: NSView!
    @IBOutlet weak var templatePopUpButton: NSPopUpButton!
    @IBOutlet weak var templateReloadButton: NSButton!
    @IBOutlet weak var splitView: NSSplitView!

    override func awakeFromNib() {
        super.awakeFromNib()

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

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.arrangedSubviews
            .forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(templatePopUpButtonWillPopUp(_:)),
            name: NSPopUpButton.willPopUpNotification,
            object: templatePopUpButton!
        )

        setNeedsReloadTemplates()
        updateStackedChildren(isAsync: false)
    }
    
    private var isViewHidden: Bool = true

    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        reloadTemplatesIfNeeded()
        resetDividersIfNeeded()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }

    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }

    private var _shouldResetDividers: Bool = false
    private var _shouldReloadTemplates: Bool = false

    deinit {
        NotificationCenter.default.removeObserver(self)
        debugPrint("\(className):\(#function)")
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) { }
}

extension ExportStackedController: StackedPaneContainer {
    
    var shouldResetDividers    : Bool { _shouldResetDividers   }
    
    func setNeedsResetDividers() {
        _shouldResetDividers = true
    }

    func resetDividersIfNeeded() {
        if _shouldResetDividers {
            _shouldResetDividers = false
            resetDividers()
        }
    }
    
    var shouldReloadTemplates  : Bool { _shouldReloadTemplates }
    
    func setNeedsReloadTemplates() {
        _shouldReloadTemplates = true
    }

    func reloadTemplatesIfNeeded() {
        if _shouldReloadTemplates {
            _shouldReloadTemplates = false
            reloadTemplates()
        }
    }

    func resetDividers(in set: IndexSet? = nil) {
        let dividerIndexes = set ?? IndexSet(integersIn: 0..<splitView.arrangedSubviews.count)
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(CGFloat.greatestFiniteMagnitude, ofDividerAt: $0) })
        }
    }
    
}

extension ExportStackedController: PaneContainer {
    var childPaneContainers      : [PaneContainer]          { children.compactMap(  { $0 as? PaneContainer  }  ) }
    var paneControllers          : [PaneController]         { children.compactMap(  { $0 as? PaneController }  ) }
    
    var templateInfoController   : TemplateInfoController?  { paneControllers.compactMap( { $0 as? TemplateInfoController } ).first }

    func focusPane(menuIdentifier identifier: NSUserInterfaceItemIdentifier, completionHandler completion: @escaping (PaneContainer) -> Void) {
        let targetViews = paneControllers
            .filter({ $0.menuIdentifier == identifier })
            .map({ $0.view })

        let targetIndexSet = splitView
            .arrangedSubviews
            .enumerated()
            .filter({ obj in
                targetViews.firstIndex(where: { $0.isDescendant(of: obj.element) }) != nil
            })
            .map({ $0.offset })
            .reduce(into: IndexSet()) { $0.insert($1) }

        DispatchQueue.main.async { [unowned self] in
            completion(self)
            self.resetDividers(in: targetIndexSet)
        }
    }
}

extension ExportStackedController: ScreenshotLoader {
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        // DO NOT MODIFY THIS METHOD
    }
    
    private func updateStackedChildren(isAsync async: Bool) {
        guard !isViewHidden else {
            setNeedsResetDividers()
            return
        }
        if async {
            DispatchQueue.main.async { [unowned self] in
                self.resetDividers()
            }
        } else {
            self.resetDividers()
        }
    }
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
        guard let template = menuItem.representedObject as? Template else { return false }
        
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
    
    @IBAction func templatePopUpButtonValueChanged(_ sender: NSPopUpButton) {
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
    
    @IBAction func reloadTemplatesItemTapped(_ sender: NSButton) {
        do {
            try TemplateManager.shared.reloadTemplates()
        } catch {
            presentError(error)
        }
    }
    
    private func generateTemplatesSubMenuItems(for menu: NSMenu) -> [NSMenuItem] {
        return TemplateManager.shared.templates
            .sorted(by: { $0.name.compare($1.name) == .orderedAscending })
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
}

extension ExportStackedController {
    @objc private func templatesDidLoad(_ noti: Notification) {
        if !isViewHidden {
            reloadTemplates()
        } else {
            setNeedsReloadTemplates()
        }
        updateStackedChildren(isAsync: true)
    }
    
    @objc private func selectedTemplateChanged(_ noti: Notification) {
        reloadTemplatesWithNotification(noti)
    }
    
    @objc private func templatePopUpButtonWillPopUp(_ noti: Notification) {
        synchronizeTitleAndSelectedItem()
    }
}
