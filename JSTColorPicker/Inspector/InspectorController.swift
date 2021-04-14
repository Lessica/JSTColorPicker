//
//  InspectorController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InspectorController: NSViewController, PaneController {
    enum Style {
        case primary
        case secondary
    }

    var menuIdentifier = NSUserInterfaceItemIdentifier("show-color-inspector")
    
    weak var screenshot  : Screenshot?
    var style            : Style = .primary

    @IBOutlet weak var paneBox        : NSBox!
    @IBOutlet weak var inspectorView  : InspectorView!
    @IBOutlet weak var detailButton   : NSButton!

    private var observableKeys        : [UserDefaults.Key] = [.togglePrimaryInspectorHSBFormat, .toggleSecondaryInspectorHSBFormat]
    private var observables           : [Observable]?
    private var lastStoredItem        : ContentItem?

    override func awakeFromNib() {
        super.awakeFromNib()
        observables = UserDefaults.standard.observe(keys: observableKeys, callback: applyDefaults(_:_:_:))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = colorPanel
        reloadPane()
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
    
    private var isViewHidden: Bool = true
    
    override func viewWillAppear() {
        super.viewWillAppear()
        isViewHidden = false
        ensurePreviewedItem(lastStoredItem)
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        isViewHidden = true
    }
}

extension InspectorController: ScreenshotLoader {
    var isPaneHidden : Bool { view.isHiddenOrHasHiddenAncestor || isViewHidden }
    var isPaneStacked: Bool { true }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        
        lastStoredItem = nil
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

    @IBAction func colorIndicatorTapped(_ sender: InspectorView) {
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = sender.colorView.color

        colorPanel.makeKeyAndOrderFront(self)
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

    func reloadPane() {
        paneBox.title = style == .primary
            ? NSLocalizedString("Inspector (Primary)", comment: "reloadPane()")
            : NSLocalizedString("Inspector (Secondary)", comment: "reloadPane()")
        prepareDefaults()
        inspectorView.reset()
    }

    @IBAction func detailButtonTapped(_ sender: NSButton) {
        inspectorView.isHSBFormat = sender.state == .on
        if style == .primary {
            UserDefaults.standard[.togglePrimaryInspectorHSBFormat] = sender.state == .on
        } else {
            UserDefaults.standard[.toggleSecondaryInspectorHSBFormat] = sender.state == .on
        }
    }
}
