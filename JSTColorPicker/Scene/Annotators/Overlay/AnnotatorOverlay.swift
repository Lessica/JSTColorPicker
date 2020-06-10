//
//  AnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class AnnotatorOverlay: EditableOverlay {
    
    public static let fixedOverlayOffset         = CGPoint(x: -12.0, y: -12.0)
    public static let fixedOverlaySize           = CGSize(width: 24.0, height: 24.0)
    public static let minimumBorderedOverlaySize = CGSize(width: 32.0, height: 32.0)
    
    public var isFixedOverlay: Bool = true
    public var label: String {
        return internalLabel
    }
    
    override var isBordered: Bool {
        return !isFixedOverlay
    }
    
    override var outerInsets: NSEdgeInsets {
        if isFixedOverlay {
            return AnnotatorOverlay.defaultOuterInsets
        }
        return super.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        if isFixedOverlay {
            return AnnotatorOverlay.defaultInnerInsets
        }
        return super.innerInsets
    }
    
    public var textColor: NSColor = .black
    public var highlightedTextColor: NSColor = .white
    public var focusedTextColor: NSColor = NSColor(srgbRed: 0.9098, green: 0.2549, blue: 0.0941, alpha: 1.0)
    public var backgroundImage: NSImage = #imageLiteral(resourceName: "Annotator")
    public var highlightedBackgroundImage: NSImage = #imageLiteral(resourceName: "AnnotatorRed")
    public var focusedBackgroundImage: NSImage = #imageLiteral(resourceName: "AnnotatorRedFocused")
    
    private static let defaultBorderWidth: CGFloat = 0.0
    private static let defaultOuterInsets = NSEdgeInsets(top: -defaultBorderWidth, left: -defaultBorderWidth, bottom: -defaultBorderWidth, right: -defaultBorderWidth)
    private static let defaultInnerInsets = NSEdgeInsets(top: defaultBorderWidth, left: defaultBorderWidth, bottom: defaultBorderWidth, right: defaultBorderWidth)
    
    private var internalLabel: String
    private lazy var internalAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: internalLabel, attributes: [
            NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular),
            NSAttributedString.Key.foregroundColor: textColor
        ])
    }()
    private lazy var internalAttributedLabelSize: CGSize = {
        return internalAttributedLabel.size()
    }()
    private lazy var internalHighlightedAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: internalLabel, attributes: [
            NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular),
            NSAttributedString.Key.foregroundColor: highlightedTextColor
        ])
    }()
    private lazy var internalHighlightedAttributedLabelSize: CGSize = {
        return internalHighlightedAttributedLabel.size()
    }()
    private lazy var internalFocusedAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: internalLabel, attributes: [
            NSAttributedString.Key.font: NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular),
            NSAttributedString.Key.foregroundColor: focusedTextColor
        ])
    }()
    private lazy var internalFocusedAttributedLabelSize: CGSize = {
        return internalFocusedAttributedLabel.size()
    }()
    
    init(label: String) {
        self.internalLabel = label
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard isFixedOverlay else {
            super.draw(dirtyRect)
            return
        }
        
        let drawBounds = bounds.inset(by: innerInsets)
        guard !drawBounds.isEmpty else { return }
        
        if isSelected {
            highlightedBackgroundImage.draw(in: drawBounds)
            internalHighlightedAttributedLabel.draw(
                with: CGRect(
                    origin: CGPoint(
                        x: drawBounds.center.x - internalHighlightedAttributedLabelSize.width / 2.0,
                        y: drawBounds.center.y - internalHighlightedAttributedLabelSize.height / 2.0
                    ),
                    size: internalHighlightedAttributedLabelSize
                ),
                options: [.usesLineFragmentOrigin]
            )
        }
        else if isFocused {
            focusedBackgroundImage.draw(in: drawBounds)
            internalFocusedAttributedLabel.draw(
                with: CGRect(
                    origin: CGPoint(
                        x: drawBounds.center.x - internalFocusedAttributedLabelSize.width / 2.0,
                        y: drawBounds.center.y - internalFocusedAttributedLabelSize.height / 2.0
                    ),
                    size: internalFocusedAttributedLabelSize
                ),
                options: [.usesLineFragmentOrigin]
            )
        }
        else {
            backgroundImage.draw(in: drawBounds)
            internalAttributedLabel.draw(
                with: CGRect(
                    origin: CGPoint(
                        x: drawBounds.center.x - internalAttributedLabelSize.width / 2.0,
                        y: drawBounds.center.y - internalAttributedLabelSize.height / 2.0
                    ),
                    size: internalAttributedLabelSize
                ),
                options: [.usesLineFragmentOrigin]
            )
        }
    }
    
}
