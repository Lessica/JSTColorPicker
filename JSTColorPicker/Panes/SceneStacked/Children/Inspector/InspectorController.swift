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

    @IBOutlet var inspectorMenu                          : NSMenu!
    @IBOutlet weak var colorSpaceOriginalItem            : NSMenuItem!
    @IBOutlet weak var colorSpaceDisplayP3Item           : NSMenuItem!
    @IBOutlet weak var colorSpaceDisplayInsRGBItem       : NSMenuItem!
    @IBOutlet weak var colorSpaceDisplayInAdobeRGBItem   : NSMenuItem!
    @IBOutlet weak var toggleHSBMenuItem                 : NSMenuItem!
    
    private var inspectorFormat        : InspectorFormat = .original
    {
        didSet {
            inspectorView.inspectorFormat = inspectorFormat
        }
    }
    
    private var isHSBFormat            : Bool = false
    {
        didSet {
            inspectorView.isHSBFormat = isHSBFormat
        }
    }
    
    @IBOutlet weak var inspectorView   : InspectorView!
    @IBOutlet weak var detailButton    : NSButton!
    override var menuIdentifier        : NSUserInterfaceItemIdentifier { NSUserInterfaceItemIdentifier("show-color-inspector") }
             var style                 : Style = .primary

    private let observableKeys         : [UserDefaults.Key] = [
        .togglePrimaryInspectorHSBFormat, .toggleSecondaryInspectorHSBFormat,
        .togglePrimaryInspectorFormat, .toggleSecondaryInspectorFormat,
    ]
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
        let hsbVal: Bool = style == .primary
            ? UserDefaults.standard[.togglePrimaryInspectorHSBFormat]
            : UserDefaults.standard[.toggleSecondaryInspectorHSBFormat]
        
        let hsbState: NSControl.StateValue = hsbVal ? .on : .off
        detailButton.state = hsbState
        
        if let formatVal: String = style == .primary
            ? UserDefaults.standard[.togglePrimaryInspectorFormat]
            : UserDefaults.standard[.toggleSecondaryInspectorFormat]
        {
            inspectorFormat = InspectorFormat(rawValue: formatVal) ?? .original
        } else {
            inspectorFormat = .original
        }
        
        isHSBFormat = hsbVal
    }

    private func applyDefaults(_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: Any) {
        if (style == .primary && defaultKey == .togglePrimaryInspectorHSBFormat) || (style == .secondary && defaultKey == .toggleSecondaryInspectorHSBFormat), let toValue = defaultValue as? Bool
        {
            let configState: NSControl.StateValue = toValue ? .on : .off
            if detailButton.state != configState {
                detailButton.state = configState
            }
            if isHSBFormat != toValue {
                isHSBFormat = toValue
            }
        }
        else if (style == .primary && defaultKey == .togglePrimaryInspectorFormat) || (style == .secondary && defaultKey == .toggleSecondaryInspectorFormat), let toValue = defaultValue as? String, let toFormat = InspectorFormat(rawValue: toValue)
        {
            if (inspectorFormat != toFormat) {
                inspectorFormat = toFormat
                
                reloadPaneTitle()
            }
        }
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        ensureLastStoredItem()
    }

    override var isPaneStacked: Bool { true }

    override func load(_ screenshot: Screenshot) throws {
        try super.load(screenshot)
        
        lastStoredItem = nil
        inspectorView.screenshot = screenshot
    }

    override func reloadPane() {
        super.reloadPane()
        
        prepareDefaults()
        reloadPaneTitle()
        inspectorView.reset()
    }
    
    private func reloadPaneTitle() {
        switch inspectorFormat {
        case .original:
            paneBox.title = style == .primary
                ? NSLocalizedString("Inspector (Primary)", comment: "reloadPane()")
                : NSLocalizedString("Inspector (Secondary)", comment: "reloadPane()")
        case .displayP3:
            paneBox.title = style == .primary
                ? NSLocalizedString("Inspector (Primary, Display P3)", comment: "reloadPane()")
                : NSLocalizedString("Inspector (Secondary, Display P3)", comment: "reloadPane()")
        case .sRGB:
            paneBox.title = style == .primary
                ? NSLocalizedString("Inspector (Primary, sRGB)", comment: "reloadPane()")
                : NSLocalizedString("Inspector (Secondary, sRGB)", comment: "reloadPane()")
        case .adobeRGB1998:
            paneBox.title = style == .primary
                ? NSLocalizedString("Inspector (Primary, Adobe RGB)", comment: "reloadPane()")
                : NSLocalizedString("Inspector (Secondary, Adobe RGB)", comment: "reloadPane()")
        }
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
        if colorPanel.isVisible, let image = screenshot?.image {
            let nsColor = color.toNSColor(with: image.colorSpace)
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
    
    private func ensureLastStoredItem() {
        ensurePreviewedItem(lastStoredItem)
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
        guard let event = view.window?.currentEvent else { return }
        NSMenu.popUpContextMenu(inspectorMenu, with: event, for: sender)
    }
}

extension InspectorController: NSMenuDelegate, NSMenuItemValidation {
    
    var defaultInspectorFormat: InspectorFormat {
        if style == .primary {
            if let inspectorFormatString: String = UserDefaults.standard[.togglePrimaryInspectorFormat] {
                return InspectorFormat(rawValue: inspectorFormatString) ?? .original
            } else {
                return .original
            }
        } else {
            if let inspectorFormatString: String = UserDefaults.standard[.toggleSecondaryInspectorFormat] {
                return InspectorFormat(rawValue: inspectorFormatString) ?? .original
            } else {
                return .original
            }
        }
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == self.inspectorMenu {
            switch defaultInspectorFormat {
            case .original:
                colorSpaceOriginalItem.state = .on
                colorSpaceDisplayP3Item.state = .off
                colorSpaceDisplayInsRGBItem.state = .off
                colorSpaceDisplayInAdobeRGBItem.state = .off
            case .displayP3:
                colorSpaceOriginalItem.state = .off
                colorSpaceDisplayP3Item.state = .on
                colorSpaceDisplayInsRGBItem.state = .off
                colorSpaceDisplayInAdobeRGBItem.state = .off
            case .sRGB:
                colorSpaceOriginalItem.state = .off
                colorSpaceDisplayP3Item.state = .off
                colorSpaceDisplayInsRGBItem.state = .on
                colorSpaceDisplayInAdobeRGBItem.state = .off
            case .adobeRGB1998:
                colorSpaceOriginalItem.state = .off
                colorSpaceDisplayP3Item.state = .off
                colorSpaceDisplayInsRGBItem.state = .off
                colorSpaceDisplayInAdobeRGBItem.state = .on
            }
            
            var hsbEnabled: Bool
            if style == .primary {
                hsbEnabled = UserDefaults.standard[.togglePrimaryInspectorHSBFormat]
            } else {
                hsbEnabled = UserDefaults.standard[.toggleSecondaryInspectorHSBFormat]
            }
            
            toggleHSBMenuItem.state = hsbEnabled ? .on : .off
        }
    }
    
    @IBAction private func toggleInspectorFormat(_ sender: NSMenuItem) {
        if sender == colorSpaceOriginalItem && defaultInspectorFormat != .original {
            if style == .primary {
                UserDefaults.standard[.togglePrimaryInspectorFormat] = InspectorFormat.original.rawValue
            } else {
                UserDefaults.standard[.toggleSecondaryInspectorFormat] = InspectorFormat.original.rawValue
            }
        }
        else if sender == colorSpaceDisplayP3Item && defaultInspectorFormat != .displayP3 {
            if style == .primary {
                UserDefaults.standard[.togglePrimaryInspectorFormat] = InspectorFormat.displayP3.rawValue
            } else {
                UserDefaults.standard[.toggleSecondaryInspectorFormat] = InspectorFormat.displayP3.rawValue
            }
        }
        else if sender == colorSpaceDisplayInsRGBItem && defaultInspectorFormat != .sRGB {
            if style == .primary {
                UserDefaults.standard[.togglePrimaryInspectorFormat] = InspectorFormat.sRGB.rawValue
            } else {
                UserDefaults.standard[.toggleSecondaryInspectorFormat] = InspectorFormat.sRGB.rawValue
            }
        }
        else if sender == colorSpaceDisplayInAdobeRGBItem && defaultInspectorFormat != .adobeRGB1998 {
            if style == .primary {
                UserDefaults.standard[.togglePrimaryInspectorFormat] = InspectorFormat.adobeRGB1998.rawValue
            } else {
                UserDefaults.standard[.toggleSecondaryInspectorFormat] = InspectorFormat.adobeRGB1998.rawValue
            }
        }
    }
    
    @IBAction private func toggleInspectorHSBFormat(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        isHSBFormat = sender.state == .on
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
