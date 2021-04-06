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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = colorPanel
        reloadPane()
    }
}

extension InspectorController: ScreenshotLoader {
    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }
    var isPaneStacked: Bool { true }

    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
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

    func inspectItem(_ item: ContentItem) {
        guard !isPaneHidden else {
            if let color = item as? PixelColor {
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
        inspectorView.reset()
        paneBox.title = style == .primary
            ? NSLocalizedString("Inspector (Primary)", comment: "reloadPane()")
            : NSLocalizedString("Inspector (Secondary)", comment: "reloadPane()")
    }
}
