//
//  InspectorView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/4.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

@IBDesignable
final class InspectorView: NSControl {
    
    private let nibName = "InspectorView"
    private var contentView: NSView?
    
    @IBOutlet weak var locationStack    : NSStackView!
    @IBOutlet weak var majorColorStack  : NSStackView!
    @IBOutlet weak var minorColorStack  : NSStackView!
    
    @IBOutlet weak var xLabel           : NSTextField!
    @IBOutlet weak var yLabel           : NSTextField!
    
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
    internal  weak var screenshot       : Screenshot?
    
    internal var inspectorFormat        : InspectorFormat = .original
    {
        didSet {
            if let contentItem = contentItem {
                setItem(contentItem)
            } else {
                reset()
            }
        }
    }
    
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
        guard let image = screenshot?.image else {
            return
        }
        
        contentItem = color
        
        let systemColor = color.toNSColor(with: image.colorSpace)
        colorView.color = systemColor
        
        hexLabel.stringValue = String(systemColor.sharpCSS.dropFirst())
        xLabel.stringValue = String(color.coordinate.x)
        yLabel.stringValue = String(color.coordinate.y)
        
        let convertedColor: NSColor?
        switch inspectorFormat {
        case .original:
            convertedColor = systemColor
        case .displayP3:
            convertedColor = systemColor.usingColorSpace(.displayP3)
        case .sRGB:
            convertedColor = systemColor.usingColorSpace(.sRGB)
        case .adobeRGB1998:
            convertedColor = systemColor.usingColorSpace(.adobeRGB1998)
        }
        
        if isHSBFormat {
            
            if let convertedColor = convertedColor {
                hueLabel.stringValue = String(Int(round(convertedColor.hueComponent * 360)))
                saturationLabel.stringValue = String(Int(round(convertedColor.saturationComponent * 100)))
                brightnessLabel.stringValue = String(Int(round(convertedColor.brightnessComponent * 100)))
            } else {
                hueLabel.stringValue = "-"
                saturationLabel.stringValue = "-"
                brightnessLabel.stringValue = "-"
            }
            
            redStack.isHidden = true
            greenStack.isHidden = true
            blueStack.isHidden = true
            hueStack.isHidden = false
            saturationStack.isHidden = false
            brightnessStack.isHidden = false
        } else {
            
            if let convertedColor = convertedColor {
                redLabel.stringValue = String(Int(round(convertedColor.redComponent * 0xFF)))
                greenLabel.stringValue = String(Int(round(convertedColor.greenComponent * 0xFF)))
                blueLabel.stringValue = String(Int(round(convertedColor.blueComponent * 0xFF)))
            } else {
                redLabel.stringValue = "-"
                greenLabel.stringValue = "-"
                blueLabel.stringValue = "-"
            }
            
            redStack.isHidden = false
            greenStack.isHidden = false
            blueStack.isHidden = false
            hueStack.isHidden = true
            saturationStack.isHidden = true
            brightnessStack.isHidden = true
        }
        
        alphaLabel.stringValue = String(Int(round(systemColor.alphaComponent * 100)))
        alphaStack.isHidden = false
        widthStack.isHidden = true
        heightStack.isHidden = true
    }
    
    func setArea(_ area: PixelArea) {
        contentItem = area
        xLabel.stringValue = String(area.rect.minX)
        yLabel.stringValue = String(area.rect.minY)
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
        xLabel.stringValue = "-"
        yLabel.stringValue = "-"
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
