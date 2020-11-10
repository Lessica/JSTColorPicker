//
//  ShortcutGuideWindowController.swift
//  JSTColorPicker
//
//  Created by Darwin on 11/1/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ShortcutGuideWindowController: NSWindowController {
    
    public static let shared = newShortcutGuideController()
    
    private static func newShortcutGuideController() -> ShortcutGuideWindowController {
        let windowStoryboard = NSStoryboard(name: "ShortcutGuide", bundle: nil)
        let sgWindowController = windowStoryboard.instantiateInitialController() as! ShortcutGuideWindowController
        return sgWindowController
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        window?.level = .statusBar
    }
    
    private func centerInScreenForWindow(_ parent: NSWindow?) {
        if let window = window, let screen = parent?.screen ?? window.screen {
            let xPos = screen.frame.minX + screen.frame.width / 2.0 - window.frame.width / 2.0
            let yPos = screen.frame.minY + screen.frame.height / 2.0 - window.frame.height / 2.0
            window.setFrame(NSRect(x: xPos, y: yPos, width: window.frame.width, height: window.frame.height), display: true)
        }
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
    public fileprivate(set) var attachedWindow: NSWindow?
    
    public func showForWindow(_ extWindow: NSWindow?) {
        rootViewController.updateDisplayWithItems(items ?? [])
        showWindow(nil)
        centerInScreenForWindow(extWindow)
        addCloseOnOutsideClick()
        attachedWindow = extWindow
    }
    
    public func hide() {
        removeCloseOnOutsideClick()
        window?.orderOut(nil)
    }
    
    public func toggleForWindow(_ extWindow: NSWindow?) {
        guard let window = window else { return }
        if !window.isVisible {
            showForWindow(extWindow)
        } else {
            hide()
        }
    }
    
    
    // MARK: - Shortcut Items
    
    public var items: [ShortcutItem]?
    private var rootViewController: ShortcutGuideViewController {
        contentViewController as! ShortcutGuideViewController
    }
    
}

extension ShortcutGuideWindowController: NSWindowDelegate {
    
    func windowDidResignKey(_ notification: Notification) {
        self.hide()
    }
    
}
