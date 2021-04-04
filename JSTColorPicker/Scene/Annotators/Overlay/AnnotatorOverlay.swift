//
//  AnnotatorOverlay.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/10/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class AnnotatorOverlay: EditableOverlay {

    
    // MARK: - Attributes

    enum RevealStyle {
        case none
        case fixed
        case centered
        case floating  // not implemented
    }

    var revealStyle         : RevealStyle = .none

    /* controlled by revealStyle */
    override var borderStyle         : BorderStyle
    {
        switch revealStyle {
        case .fixed:
            return .none
        case .centered, .floating:
            return .solid
        default:
            return super.borderStyle
        }
    }

    /* controlled by revealStyle */
    override var isHighlighted       : Bool
    {
        get {
            revealStyle != .none ? true : super.isHighlighted
        }
        set {
            super.isHighlighted = newValue
        }
    }

    
    // MARK: - Inherited
    
    override var outerInsets: NSEdgeInsets {
        if revealStyle == .fixed {
            return AnnotatorOverlay.defaultOuterInsets
        }
        return super.outerInsets
    }
    
    override var innerInsets: NSEdgeInsets {
        if revealStyle == .fixed {
            return AnnotatorOverlay.defaultInnerInsets
        }
        return super.innerInsets
    }
    
    
    // MARK: - Appearance

    /* Fixed Appearance */
    static let fixedOverlayOffset             = CGPoint(x: -12.0, y: -12.0)
    static let fixedOverlaySize               = CGSize(width: 24.0, height: 24.0)
    static let minimumBorderedOverlaySize     = CGSize(width: 16.0, height: 16.0)
    
    var labelColor                            : NSColor = .black
    var selectedLabelColor                    : NSColor = .white
    var focusedLabelColor                     : NSColor = .clear

    var backgroundImage                       : NSImage = NSImage(size: .zero)
    var selectedBackgroundImage               : NSImage = NSImage(size: .zero)
    var focusedBackgroundImage                : NSImage = NSImage(size: .zero)

    private static let labelFont                     = NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular)
    private static let defaultBorderWidth            : CGFloat = 0.0
    private static let defaultOuterInsets            = NSEdgeInsets(
        top: -defaultBorderWidth,
        left: -defaultBorderWidth,
        bottom: -defaultBorderWidth,
        right: -defaultBorderWidth
    )
    private static let defaultInnerInsets            = NSEdgeInsets(
        top: defaultBorderWidth,
        left: defaultBorderWidth,
        bottom: defaultBorderWidth,
        right: defaultBorderWidth
    )

    /* Revealed Appearance (.centered) */
    var associatedLabelColor                  : NSColor?
    var associatedBackgroundColor             : NSColor?
    private static let associatedLabelFont           = NSFont.monospacedDigitSystemFont(ofSize: 13.0, weight: .regular)
    
    
    // MARK: - Label
    
    var label                      : String   { _internalLabel           }
    var associatedLabel            : String?  { _internalAssociatedLabel }
    private var _internalLabel            : String
    private var _internalAssociatedLabel  : String?

    /* Label */
    private lazy var internalAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: _internalLabel, attributes: [
            NSAttributedString.Key.font: AnnotatorOverlay.labelFont,
            NSAttributedString.Key.foregroundColor: labelColor
        ])
    }()
    private lazy var internalAttributedLabelSize: CGSize = {
        return internalAttributedLabel.size()
    }()

    private lazy var internalSelectedAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: _internalLabel, attributes: [
            NSAttributedString.Key.font: AnnotatorOverlay.labelFont,
            NSAttributedString.Key.foregroundColor: selectedLabelColor
        ])
    }()
    private lazy var internalSelectedAttributedLabelSize: CGSize = {
        return internalSelectedAttributedLabel.size()
    }()

    private lazy var internalFocusedAttributedLabel: NSAttributedString = {
        return NSAttributedString(string: _internalLabel, attributes: [
            NSAttributedString.Key.font: AnnotatorOverlay.labelFont,
            NSAttributedString.Key.foregroundColor: focusedLabelColor
        ])
    }()
    private lazy var internalFocusedAttributedLabelSize: CGSize = {
        return internalFocusedAttributedLabel.size()
    }()

    /* Associated Label */
    private lazy var internalAttributedAssociatedLabel: NSAttributedString? = {
        guard let _internalAssociatedLabel = _internalAssociatedLabel,
              let associatedLabelColor = associatedLabelColor
        else { return nil }
        return NSAttributedString(string: _internalAssociatedLabel, attributes: [
            NSAttributedString.Key.font: AnnotatorOverlay.associatedLabelFont,
            NSAttributedString.Key.foregroundColor: associatedLabelColor
        ])
    }()
    private lazy var internalAttributedAssociatedLabelSize: CGSize? = {
        guard let internalAttributedAssociatedLabel = internalAttributedAssociatedLabel else { return nil }
        return internalAttributedAssociatedLabel.size()
    }()
    
    
    // MARK: - Initializers
    
    init(label: String, associatedLabel: String? = nil) {
        self._internalLabel = label
        self._internalAssociatedLabel = associatedLabel
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    // MARK: - Drawing
    
    override func draw(_ dirtyRect: NSRect) {
        if revealStyle == .none {
            super.draw(dirtyRect)
        }
        else if revealStyle == .fixed {
            let drawBounds = bounds.inset(by: innerInsets)
            guard !drawBounds.isEmpty else { return }

            if isSelected {
                selectedBackgroundImage.draw(in: drawBounds)
                internalSelectedAttributedLabel.draw(
                    with: CGRect(
                        origin: CGPoint(
                            x: drawBounds.center.x - internalSelectedAttributedLabelSize.width / 2.0,
                            y: drawBounds.center.y - internalSelectedAttributedLabelSize.height / 2.0
                        ),
                        size: internalSelectedAttributedLabelSize
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
        else if revealStyle == .centered {
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }

            // draws background
            if isFocused || isSelected {
                let backgroundColor = associatedBackgroundColor ?? NSColor.controlAccentColor.withAlphaComponent(0.2)

                let drawBounds = bounds.inset(by: innerInsets)
                guard !drawBounds.isEmpty else { return }

                let backgroundBounds = drawBounds.intersection(dirtyRect)

                ctx.setFillColor(backgroundColor.cgColor)
                ctx.fill(backgroundBounds)
            }

            // draws text
            var usedText: NSAttributedString?
            var usedTextSize: CGSize?
            if isFocused || isSelected
            {
                // draws only when selected for this style
                usedText = internalAttributedAssociatedLabel
                usedTextSize = internalAttributedAssociatedLabelSize
            }

            if let text = usedText, let textSize = usedTextSize {
                let textRect = CGRect(
                    origin: bounds.center.offsetBy(dx: -textSize.width / 2.0, dy: -textSize.height / 2.0),
                    size: textSize
                )
                if dirtyRect.intersects(textRect) && dirtyRect.contains(textRect) {
                    text.draw(with: textRect, options: [.usesLineFragmentOrigin])
                }
            }

            super.draw(dirtyRect)
        }
    }
    
}

