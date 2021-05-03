//
//  InspectorView.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/4.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@IBDesignable
class InspectorView: NSControl {
    private let nibName = "InspectorView"
    private var contentView: NSView?
    
    @IBOutlet weak var colorView        : ColorIndicator!
    @IBOutlet weak var hexLabel         : NSTextField!
    @IBOutlet weak var redLabel         : NSTextField!
    @IBOutlet weak var greenLabel       : NSTextField!
    @IBOutlet weak var blueLabel        : NSTextField!
    @IBOutlet weak var hueLabel         : NSTextField!
    @IBOutlet weak var saturationLabel  : NSTextField!
    @IBOutlet weak var brightnessLabel  : NSTextField!
    @IBOutlet weak var alphaLabel       : NSTextField!
    @IBOutlet weak var widthLabel       : NSTextField!
    @IBOutlet weak var heightLabel      : NSTextField!
    
    @IBOutlet weak var redStack         : NSStackView!
    @IBOutlet weak var greenStack       : NSStackView!
    @IBOutlet weak var blueStack        : NSStackView!
    @IBOutlet weak var hueStack         : NSStackView!
    @IBOutlet weak var saturationStack  : NSStackView!
    @IBOutlet weak var brightnessStack  : NSStackView!
    @IBOutlet weak var alphaStack       : NSStackView!
    @IBOutlet weak var widthStack       : NSStackView!
    @IBOutlet weak var heightStack      : NSStackView!

    private   weak var contentItem      : ContentItem?
    @IBInspectable var isHSBFormat      : Bool = false
    {
        didSet {
            if let contentItem = contentItem {
                setItem(contentItem)
            } else {
                reset()
            }
        }
    }
    
    @IBAction private func colorIndicatorTapped(_ sender: ColorIndicator) {
        if let action = action {
            NSApp.sendAction(action, to: self.target, from: self)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        guard let view = loadViewFromNib() else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        contentView = view
    }
    
    func loadViewFromNib() -> NSView? {
        var views: NSArray?
        guard NSNib(nibNamed: nibName, bundle: Bundle(for: type(of: self)))!.instantiate(withOwner: self, topLevelObjects: &views)
        else { return nil }
        return views?.compactMap({ $0 as? NSView }).first
    }

    func setItem(_ item: ContentItem) {
        if let color = item as? PixelColor {
            setColor(color)
        } else if let area = item as? PixelArea {
            setArea(area)
        }
    }
    
    func setColor(_ color: PixelColor) {
        contentItem = color
        colorView.color = color.toNSColor()
        hexLabel.stringValue = String(color.cssString.dropFirst())
        if isHSBFormat {
            hueLabel.stringValue = String(Int(color.hue))
            saturationLabel.stringValue = String(Int(color.saturation * 100))
            brightnessLabel.stringValue = String(Int(color.brightness * 100))
            redStack.isHidden = true
            greenStack.isHidden = true
            blueStack.isHidden = true
            hueStack.isHidden = false
            saturationStack.isHidden = false
            brightnessStack.isHidden = false
        } else {
            redLabel.stringValue = String(color.red)
            greenLabel.stringValue = String(color.green)
            blueLabel.stringValue = String(color.blue)
            redStack.isHidden = false
            greenStack.isHidden = false
            blueStack.isHidden = false
            hueStack.isHidden = true
            saturationStack.isHidden = true
            brightnessStack.isHidden = true
        }
        alphaLabel.stringValue = String(Int(Double(color.alpha) / 0xFF * 100))
        alphaStack.isHidden = false
        widthStack.isHidden = true
        heightStack.isHidden = true
    }
    
    func setArea(_ area: PixelArea) {
        contentItem = area
        widthLabel.stringValue = String(area.rect.width)
        heightLabel.stringValue = String(area.rect.height)
        redStack.isHidden = true
        greenStack.isHidden = true
        blueStack.isHidden = true
        hueStack.isHidden = true
        saturationStack.isHidden = true
        brightnessStack.isHidden = true
        alphaStack.isHidden = true
        widthStack.isHidden = false
        heightStack.isHidden = false
    }
    
    func reset() {
        colorView.color = .clear
        redLabel.stringValue = "-"
        greenLabel.stringValue = "-"
        blueLabel.stringValue = "-"
        hueLabel.stringValue = "-"
        saturationLabel.stringValue = "-"
        brightnessLabel.stringValue = "-"
        alphaLabel.stringValue = "-"
        hexLabel.stringValue = "-"
        widthLabel.stringValue = "-"
        heightLabel.stringValue = "-"
        if isHSBFormat {
            redStack.isHidden = true
            greenStack.isHidden = true
            blueStack.isHidden = true
            hueStack.isHidden = false
            saturationStack.isHidden = false
            brightnessStack.isHidden = false
        } else {
            redStack.isHidden = false
            greenStack.isHidden = false
            blueStack.isHidden = false
            hueStack.isHidden = true
            saturationStack.isHidden = true
            brightnessStack.isHidden = true
        }
        alphaStack.isHidden = false
        widthStack.isHidden = true
        heightStack.isHidden = true
    }

    
}
