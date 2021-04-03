//
//  InspectorController.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/1.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

class InspectorController: NSViewController, PaneController {
    internal weak var screenshot: Screenshot?

    @IBOutlet weak var paneBox                   : NSBox!
    
    @IBOutlet weak var inspectorView1            : InspectorView!
    @IBOutlet weak var inspectorView2            : InspectorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        _ = colorPanel
        reloadPane()
    }
}

extension InspectorController: ScreenshotLoader {
    var isPaneHidden: Bool { view.isHiddenOrHasHiddenAncestor }

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

    @IBAction func colorIndicatorTapped(_ sender: InspectorView) {
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = sender.colorView.color

        colorPanel.makeKeyAndOrderFront(self)
    }

    func inspectItem(_ item: ContentItem, shouldSubmit submit: Bool) {
        guard !isPaneHidden else {
            if let color = item as? PixelColor,
               submit && colorPanel.isVisible
            {
                let nsColor = color.toNSColor()
                colorPanel.setTarget(nil)
                colorPanel.setAction(nil)
                colorPanel.color = nsColor
            }
            return
        }

        if let color = item as? PixelColor {
            if !submit {
                inspectorView1.setColor(color)
            } else {
                inspectorView2.setColor(color)
                if colorPanel.isVisible {
                    let nsColor = color.toNSColor()
                    colorPanel.setTarget(nil)
                    colorPanel.setAction(nil)
                    colorPanel.color = nsColor
                }
            }
        }
        else if let area = item as? PixelArea {
            if !submit {
                inspectorView1.setArea(area)
            } else {
                inspectorView2.setArea(area)
            }
        }
    }

    func reloadPane() {
        inspectorView1.reset()
        inspectorView2.reset()
    }
}
