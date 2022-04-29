//
//  InspectorController.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class InspectorController: StackedPaneController {
    enum Style {
        case primary
        case secondary
    }

    @IBOutlet weak var inspectorView   : InspectorView!
    @IBOutlet weak var detailButton    : NSButton!
    override var menuIdentifier        : NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-color-inspector") }
             var style                 : Style = .primary

    private let observableKeys         : [UserDefaults.Key] = [.togglePrimaryInspectorHSBFormat, .toggleSecondaryInspectorHSBFormat]
    private var observables            : [Observable]?
    
    private var isRestorable           : Bool { style == .secondary }
    private var lastStoredItem         : ContentItem? {
        didSet {
            if isRestorable {
                invalidateRestorableState()
            }
        }
    }

    override func viewDidLoad() {
        _ = colorPanel
        super.viewDidLoad()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: { [weak self] in self?.applyDefaults($0, $1, $2) })
    }

    private func prepareDefaults() {
        let configVal: Bool = style == .primary
            ? UserDefaults.standard[.togglePrimaryInspectorHSBFormat]
            : UserDefaults.standard[.toggleSecondaryInspectorHSBFormat]
        let configState: NSControl.StateValue = configVal ? .on : .off
        detailButton.state = configState
        inspectorView.isHSBFormat = configVal
    }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if (style == .primary && defaultKey == .togglePrimaryInspectorHSBFormat) || (style == .secondary && defaultKey == .toggleSecondaryInspectorHSBFormat), let toValue = defaultValue as? Bool
        {
            let configState: NSControl.StateValue = toValue ? .on : .off
            if detailButton.state != configState {
                detailButton.state = configState
            }
            if inspectorView.isHSBFormat != toValue {
                inspectorView.isHSBFormat = toValue
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        ensurePreviewedItem(lastStoredItem)
    }

    override var isPaneStacked: Bool { true }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        lastStoredItem = nil
    }

    override func reloadPane() {
        super.reloadPane()
        paneBox.title = style == .primary
            ? NSLocalizedString("Inspector (Primary)", comment: "reloadPane()")
            : NSLocalizedString("Inspector (Secondary)", comment: "reloadPane()")
        prepareDefaults()
        inspectorView.reset()
    }
}

extension InspectorController: ItemInspector {
    private var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.touchBar = nil
        return panel
    }

    private func colorPanelSetColor(_ color: PixelColor) {
        if colorPanel.isVisible {
            let nsColor = color.toNSColor()
            colorPanel.setTarget(nil)
            colorPanel.setAction(nil)
            colorPanel.color = nsColor
        }
    }

    @IBAction private func colorIndicatorTapped(_ sender: InspectorView) {
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = sender.colorView.color

        colorPanel.makeKeyAndOrderFront(sender)
    }
    
    private func ensurePreviewedItem(_ item: ContentItem?) {
        guard let item = item else { return }
        inspectItem(item)
    }

    func inspectItem(_ item: ContentItem) {
        lastStoredItem = item
        
        guard !isPaneHidden else {
            if let color = item as? PixelColor, style == .secondary {
                colorPanelSetColor(color)
            }
            return
        }

        if let color = item as? PixelColor {
            inspectorView.setColor(color)
            if style == .secondary {
                colorPanelSetColor(color)
            }
        } else if let area = item as? PixelArea {
            inspectorView.setArea(area)
        }
    }

    @IBAction private func detailButtonTapped(_ sender: NSButton) {
        inspectorView.isHSBFormat = sender.state == .on
        if style == .primary {
            UserDefaults.standard[.togglePrimaryInspectorHSBFormat] = sender.state == .on
        } else {
            UserDefaults.standard[.toggleSecondaryInspectorHSBFormat] = sender.state == .on
        }
    }
}

extension InspectorController {
    
    private var restorableStoredItemState: String {
        switch style {
        case .primary:
            return "InspectorController.primary.lastStoredItem"
        case .secondary:
            return "InspectorController.secondary.lastStoredItem"
        }
    }

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        if isRestorable {
            coder.encode(lastStoredItem, forKey: restorableStoredItemState)
        }
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if isRestorable, let storedItem = coder.decodeObject(of: ContentItem.self, forKey: restorableStoredItemState)
        {
            ensurePreviewedItem(storedItem)
        }
    }
    
}
