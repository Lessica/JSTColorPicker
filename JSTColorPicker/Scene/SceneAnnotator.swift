//
//  SceneAnnotator.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/29/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

class VerticallyCenteredTextFieldCell : NSTextFieldCell {
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)

        let minimumHeight = self.cellSize(forBounds: rect).height
        titleRect.origin.y += (titleRect.height - minimumHeight) / 2
        titleRect.size.height = minimumHeight

        return titleRect
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }
    
}

class SceneAnnotator {
    
    var pixelColor: PixelColor
    var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundCell.stringValue = "🔴"
                labelCell.textColor = .white
            } else {
                backgroundCell.stringValue = "⚪️"
                labelCell.textColor = .black
            }
        }
    }
    var label: String {
        didSet {
            labelCell.stringValue = label
        }
    }
    var view: NSView
    fileprivate var backgroundCell: VerticallyCenteredTextFieldCell
    fileprivate var labelCell: VerticallyCenteredTextFieldCell
    
    init(pixelColor: PixelColor) {
        let view = NSView()
        
        let backgroundCell = VerticallyCenteredTextFieldCell()
        backgroundCell.isEditable = false
        backgroundCell.isSelectable = false
        backgroundCell.isBezeled = false
        backgroundCell.isBordered = false
        backgroundCell.drawsBackground = false
        backgroundCell.alignment = .center
        backgroundCell.lineBreakMode = .byClipping
        backgroundCell.font = NSFont.systemFont(ofSize: 18.0)
        let backgroundView = NSTextField()
        backgroundView.cell = backgroundCell
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundCell = backgroundCell
        view.addSubview(backgroundView)
        view.addConstraints([
            NSLayoutConstraint(item: backgroundView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        ])
        
        let labelCell = VerticallyCenteredTextFieldCell()
        labelCell.isEditable = false
        labelCell.isSelectable = false
        labelCell.isBezeled = false
        labelCell.isBordered = false
        labelCell.drawsBackground = false
        labelCell.alignment = .center
        labelCell.lineBreakMode = .byClipping
        labelCell.font = NSFont.systemFont(ofSize: 12.0)
        let labelView = NSTextField()
        labelView.cell = labelCell
        labelView.translatesAutoresizingMaskIntoConstraints = false
        self.labelCell = labelCell
        view.addSubview(labelView)
        view.addConstraints([
            NSLayoutConstraint(item: labelView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        ])
        
        view.alphaValue = 0.85
        
        // setup view
        self.pixelColor = pixelColor
        self.isHighlighted = false
        self.label = "0"
        self.view = view
    }
    
}

