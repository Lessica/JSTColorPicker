//
//  ShortcutGuideWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

public enum ShortcutGuideColumnStyle {
    case single
    case dual
}

public class ShortcutGuideWindowController: NSWindowController {
    
    public static let shared = newShortcutGuideController()
    
    private static func newShortcutGuideController() -> ShortcutGuideWindowController {
        let windowStoryboard = NSStoryboard(name: "ShortcutGuide", bundle: nil)
        let sgWindowController = windowStoryboard.instantiateInitialController() as! ShortcutGuideWindowController
        return sgWindowController
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .statusBar
    }
    
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    deinit {
        // Clean up click recognizer
        removeCloseOnOutsideClick()
    }
    
    /**
     Creates a monitor for outside clicks. If clicking outside of this view or
     any views in `ignoringViews`, the view will be hidden.
     */
    private func addCloseOnOutsideClick(ignoring ignoringViews: [NSView]? = nil) {
        
        guard let window = window, let contentView = window.contentView else { return }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] (event) -> NSEvent? in
            
            let localLoc = contentView.convert(event.locationInWindow, from: nil)
            if !contentView.bounds.contains(localLoc) && window.isVisible == true {
                
                // If the click is in any of the specified views to ignore, don't hide
                for ignoreView in ignoringViews ?? [NSView]() {
                    let frameInWindow: NSRect = ignoreView.convert(ignoreView.bounds, to: nil)
                    if frameInWindow.contains(event.locationInWindow) {
                        // Abort if clicking in an ignored view
                        return event
                    }
                }
                
                // Getting here means the click should hide the view
                // Perform your hiding code here
                self?.hide()
                
            }
            
            return event
            
        })
        
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] (event) -> Void in
            if window.isVisible == true {
                self?.hide()
            }
        }
        
    }
    
    
    private func removeCloseOnOutsideClick() {
        if localMonitor != nil {
            NSEvent.removeMonitor(localMonitor!)
            localMonitor = nil
        }
        if globalMonitor != nil {
            NSEvent.removeMonitor(globalMonitor!)
            globalMonitor = nil
        }
    }
    
    
    // MARK: - Toggle
    
    public var isVisible: Bool { window?.isVisible ?? false }
    public private(set) var attachedWindow: NSWindow? {
        get {
            rootViewController.attachedWindow
        }
        set {
            rootViewController.attachedWindow = newValue
        }
    }
    
    public func showForWindow(_ extWindow: NSWindow?, columnStyle style: ShortcutGuideColumnStyle = .dual) {
        attachedWindow = extWindow
        prepareForPresentation(columnStyle: style)
        showWindow(nil)
        addCloseOnOutsideClick()
    }
    
    public func hide() {
        removeCloseOnOutsideClick()
        window?.orderOut(nil)
    }
    
    public func toggleForWindow(_ extWindow: NSWindow?, columnStyle style: ShortcutGuideColumnStyle = .dual) {
        guard let window = window else { return }
        if !window.isVisible {
            showForWindow(extWindow, columnStyle: style)
        } else {
            hide()
        }
    }
    
    
    // MARK: - Shortcut Items

    public var items: [ShortcutItem]? {
        get {
            rootViewController.items
        }
        set {
            rootViewController.items = newValue
        }
    }

    private var rootViewController: ShortcutGuidePageController {
        contentViewController as! ShortcutGuidePageController
    }

    private func prepareForPresentation(columnStyle style: ShortcutGuideColumnStyle) {
        rootViewController.prepareForPresentation(columnStyle: style)
    }
    
}

extension ShortcutGuideWindowController: NSWindowDelegate {
    
    public func windowDidResignKey(_ notification: Notification) {
        self.hide()
    }
    
}
