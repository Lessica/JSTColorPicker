//
//  AnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

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

class AnnotatorOverlay: EditableOverlay {
    
    let defaultOffset = CGPoint(x: -15.5, y: -16.5)
    let defaultSize = CGSize(width: 32.0, height: 32.0)
    
    var backgroundCell: VerticallyCenteredTextFieldCell
    var labelCell: VerticallyCenteredTextFieldCell
    
    var backgroundView: NSTextField
    var labelView: NSTextField
    
    var isSmallArea: Bool = true {
        didSet {
            backgroundView.isHidden = !isSmallArea
            labelView.isHidden = !isSmallArea
        }
    }
    
    override var isBordered: Bool {
        return !isSmallArea
    }
    
    override var isEditable: Bool {
        return !isSmallArea
    }
    
    override init(frame frameRect: NSRect) {
        backgroundCell = VerticallyCenteredTextFieldCell()
        backgroundCell.isEditable = false
        backgroundCell.isSelectable = false
        backgroundCell.isBezeled = false
        backgroundCell.isBordered = false
        backgroundCell.drawsBackground = false
        backgroundCell.alignment = .center
        backgroundCell.lineBreakMode = .byClipping
        backgroundCell.font = NSFont.systemFont(ofSize: 18.0)
        backgroundView = NSTextField()
        backgroundView.cell = backgroundCell
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        labelCell = VerticallyCenteredTextFieldCell()
        labelCell.isEditable = false
        labelCell.isSelectable = false
        labelCell.isBezeled = false
        labelCell.isBordered = false
        labelCell.drawsBackground = false
        labelCell.alignment = .center
        labelCell.lineBreakMode = .byClipping
        labelCell.font = NSFont.systemFont(ofSize: 12.0)
        labelView = NSTextField()
        labelView.cell = labelCell
        labelView.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(frame: .zero)
        
        addSubview(backgroundView)
        addConstraints([
            NSLayoutConstraint(item: backgroundView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: backgroundView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        ])
        addSubview(labelView)
        addConstraints([
            NSLayoutConstraint(item: labelView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: labelView, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1.0, constant: 0.0)
        ])
        
        backgroundCell.stringValue = ""
        
        labelCell.stringValue = ""
        labelCell.textColor = .black
        
        backgroundView.isHidden = true
        labelView.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
