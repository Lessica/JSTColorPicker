//
//  ShortcutGuideViewController.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ShortcutGuideViewController: NSViewController {
    
    @IBOutlet var visualEffectView: NSVisualEffectView!
    
    @IBOutlet weak var nothingLabel:      NSTextField!
    @IBOutlet weak var pageStackView:     NSStackView!
    @IBOutlet weak var columnStackView1:  NSStackView!
    @IBOutlet weak var columnDivider:     NSBox!
    @IBOutlet weak var columnStackView2:  NSStackView!
    
    @IBOutlet weak var itemWrapperView1:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView2:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView3:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView4:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView5:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView6:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView7:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView8:  ShortcutItemView!
    
    @IBOutlet weak var itemWrapperView9:  ShortcutItemView!
    @IBOutlet weak var itemWrapperView10: ShortcutItemView!
    @IBOutlet weak var itemWrapperView11: ShortcutItemView!
    @IBOutlet weak var itemWrapperView12: ShortcutItemView!
    @IBOutlet weak var itemWrapperView13: ShortcutItemView!
    @IBOutlet weak var itemWrapperView14: ShortcutItemView!
    @IBOutlet weak var itemWrapperView15: ShortcutItemView!
    @IBOutlet weak var itemWrapperView16: ShortcutItemView!
    
    private lazy var itemWrappers: [ShortcutItemView] = {
        [
            itemWrapperView1,
            itemWrapperView2,
            itemWrapperView3,
            itemWrapperView4,
            itemWrapperView5,
            itemWrapperView6,
            itemWrapperView7,
            itemWrapperView8,
            itemWrapperView9,
            itemWrapperView10,
            itemWrapperView11,
            itemWrapperView12,
            itemWrapperView13,
            itemWrapperView14,
            itemWrapperView15,
            itemWrapperView16,
        ]
    }()
    
    private func maskImage(cornerRadius: CGFloat) -> NSImage {
        let edgeLength = 2.0 * cornerRadius + 1.0
        let maskImage = NSImage(size: NSSize(width: edgeLength, height: edgeLength), flipped: false) { rect in
            let bezierPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.black.set()
            bezierPath.fill()
            return true
        }
        maskImage.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        maskImage.resizingMode = .stretch
        return maskImage
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .appearanceBased
        visualEffectView.state = .active
        visualEffectView.maskImage = maskImage(cornerRadius: 16.0)
        view.window?.contentView = visualEffectView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateDisplayWithItems([])
        updateDisplayWithItems([
            ShortcutItem(name: "Copy", keyString: "C", modifierFlags: [.command])
        ])
        updateDisplayWithItems([
            ShortcutItem(name: "Copy", keyString: "C", modifierFlags: [.command]),
            ShortcutItem(name: "Save As...", keyString: "S", modifierFlags: [.shift, .command])
        ])
    }
    
    public func updateDisplayWithItems(_ items: [ShortcutItem]) {
        nothingLabel.isHidden = items.count != 0
        pageStackView.isHidden = items.count == 0
        columnStackView1.isHidden = items.count == 0
        columnDivider.isHidden = items.count <= 8
        columnStackView2.isHidden = items.count <= 8
        var itemIdx = 0
        for itemWrapper in itemWrappers {
            itemWrapper.isHidden = items.count <= itemIdx
            if items.count > itemIdx {
                itemWrapper.updateDisplayWithItem(items[itemIdx])
            } else {
                itemWrapper.resetDisplay()
            }
            itemIdx += 1
        }
    }
    
}
