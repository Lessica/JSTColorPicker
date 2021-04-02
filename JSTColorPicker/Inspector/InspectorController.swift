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
    
    @IBOutlet weak var inspectorColorLabel       : NSTextField!
    @IBOutlet weak var inspectorColorFlag        : ColorIndicator!
    @IBOutlet weak var inspectorAreaLabel        : NSTextField!

    @IBOutlet weak var inspectorColorLabelAlt    : NSTextField!
    @IBOutlet weak var inspectorColorFlagAlt     : ColorIndicator!
    @IBOutlet weak var inspectorAreaLabelAlt     : NSTextField!

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

    @IBAction func colorIndicatorTapped(_ sender: ColorIndicator) {
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.color = sender.color

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
                inspectorColorLabel.stringValue = """
R:\(String(color.red).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.red).leftPadding(to: 6, with: " "))
G:\(String(color.green).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.green).leftPadding(to: 6, with: " "))
B:\(String(color.blue).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.blue).leftPadding(to: 6, with: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(to: 5, with: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(to: 5, with: " "))
"""
                let nsColor = color.toNSColor()
                inspectorColorFlag.color = nsColor
                inspectorColorFlag.setImage(NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size))
                inspectorAreaLabel.stringValue = """
CSS:\(color.cssString.leftPadding(to: 9, with: " "))
\(color.coordinate.description.leftPadding(to: 13, with: " "))
"""
            }
            else {
                inspectorColorLabelAlt.stringValue = """
R:\(String(color.red).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.red).leftPadding(to: 6, with: " "))
G:\(String(color.green).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.green).leftPadding(to: 6, with: " "))
B:\(String(color.blue).leftPadding(to: 5, with: " "))\(String(format: "0x%02X", color.blue).leftPadding(to: 6, with: " "))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(to: 5, with: " "))%\(String(format: "0x%02X", color.alpha).leftPadding(to: 5, with: " "))
"""
                let nsColor = color.toNSColor()
                inspectorColorFlagAlt.color = nsColor
                inspectorColorFlagAlt.setImage(NSImage.init(color: nsColor, size: inspectorColorFlag.bounds.size))
                inspectorAreaLabelAlt.stringValue = """
CSS:\(color.cssString.leftPadding(to: 9, with: " "))
\(color.coordinate.description.leftPadding(to: 13, with: " "))
"""
                if colorPanel.isVisible {
                    colorPanel.setTarget(nil)
                    colorPanel.setAction(nil)
                    colorPanel.color = nsColor
                }
            }
        }
        else if let area = item as? PixelArea {
            if !submit {
                inspectorAreaLabel.stringValue = """
W:\(String(area.rect.width).leftPadding(to: 11, with: " "))
H:\(String(area.rect.height).leftPadding(to: 11, with: " "))
"""
            }
            else {
                inspectorAreaLabelAlt.stringValue = """
W:\(String(area.rect.width).leftPadding(to: 11, with: " "))
H:\(String(area.rect.height).leftPadding(to: 11, with: " "))
"""
            }
        }
    }

    func reloadPane() {
        inspectorColorFlag.setImage(NSImage(color: .clear, size: inspectorColorFlag.bounds.size))
        inspectorColorLabel.stringValue = """
R:\("-".leftPadding(to: 11, with: " "))
G:\("-".leftPadding(to: 11, with: " "))
B:\("-".leftPadding(to: 11, with: " "))
A:\("-".leftPadding(to: 11, with: " "))
"""
        inspectorAreaLabel.stringValue = """
CSS:\("-".leftPadding(to: 9, with: " "))
\("-".leftPadding(to: 13, with: " "))
"""
        inspectorColorFlagAlt.setImage(NSImage(color: .clear, size: inspectorColorFlagAlt.bounds.size))
        inspectorColorLabelAlt.stringValue = """
R:\("-".leftPadding(to: 11, with: " "))
G:\("-".leftPadding(to: 11, with: " "))
B:\("-".leftPadding(to: 11, with: " "))
A:\("-".leftPadding(to: 11, with: " "))
"""
        inspectorAreaLabelAlt.stringValue = """
CSS:\("-".leftPadding(to: 9, with: " "))
\("-".leftPadding(to: 13, with: " "))
"""
    }
}
