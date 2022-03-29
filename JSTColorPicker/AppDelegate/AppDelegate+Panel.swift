//
//  AppDelegate+Panel.swift
//  JSTColorPicker
//
//  Created by Rachel on 6/8/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa


extension NSUserInterfaceItemIdentifier {
    private static let panelPrefix     = "com.jst.JSTColorPicker.Panel."
    
    static let panelBrowser     = Self(Self.panelPrefix + "Browser"     )
    static let panelColorPanel  = Self(Self.panelPrefix + "ColorPanel"  )
    static let panelColorGrid   = Self(Self.panelPrefix + "ColorGrid"   )
}


extension AppDelegate {
    @IBAction private func panelSwitchMenuItemTapped(_ sender: NSMenuItem) {
        if let senderIdentifier = sender.identifier {
            switch senderIdentifier {
                case .panelBrowser:
                    browserSwitch(sender)
                case .panelColorGrid:
                    colorGridSwitch(sender)
                case .panelColorPanel:
                    colorPanelSwitch(sender)
                default:
                    break
            }
        }
    }
}


extension AppDelegate {
    
    // MARK: - Browser Actions
    
    internal var isBrowserVisible: Bool {
        guard BrowserWindowController.sharedLoaded else { return false }
        return BrowserWindowController.shared.isVisible
    }
    
    internal func toggleBrowserVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            BrowserWindowController.shared.showWindow(sender)
        } else {
            if BrowserWindowController.sharedLoaded {
                BrowserWindowController.shared.close()
            }
        }
        NSApp.invalidateRestorableState()
    }
    
    @objc private func browserSwitch(_ sender: Any?) {
        if isBrowserVisible {
            toggleBrowserVisibleState(false, sender: sender)
        } else {
            toggleBrowserVisibleState(true, sender: sender)
        }
    }
    
}


extension AppDelegate {
    
    // MARK: - Color Grid Actions
    
    internal var isColorGridVisible: Bool {
        guard GridWindowController.sharedLoaded else { return false }
        return GridWindowController.shared.isVisible
    }
    
    internal func toggleColorGridVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            let sharedGridWindowController = GridWindowController.shared
            sharedGridWindowController.activeWindowController = firstRespondingWindowController
            sharedGridWindowController.showWindow(sender)
        } else {
            if GridWindowController.sharedLoaded {
                GridWindowController.shared.close()
            }
        }
        NSApp.invalidateRestorableState()
    }
    
    @objc private func colorGridSwitch(_ sender: Any?) {
        if isColorGridVisible {
            toggleColorGridVisibleState(false, sender: sender)
        } else {
            toggleColorGridVisibleState(true, sender: sender)
        }
    }
    
}


extension AppDelegate {
    
    // MARK: - Color Panel Actions
    
    var colorPanel: NSColorPanel {
        let panel = NSColorPanel.shared
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.touchBar = nil
        return panel
    }
    
    internal var isColorPanelVisible: Bool { colorPanel.isVisible }
    
    internal func toggleColorPanelVisibleState(_ visible: Bool, sender: Any?) {
        if visible {
            colorPanel.makeKeyAndOrderFront(sender)
        } else {
            colorPanel.close()
        }
        NSApp.invalidateRestorableState()
    }
    
    @objc private func colorPanelSwitch(_ sender: Any?) {
        if isColorPanelVisible {
            toggleColorPanelVisibleState(false, sender: sender)
        } else {
            toggleColorPanelVisibleState(true, sender: sender)
        }
    }
    
}

