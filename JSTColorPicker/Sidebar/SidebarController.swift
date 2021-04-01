//
//  SidebarController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSUserInterfaceItemIdentifier {
    static let togglePaneViewInformation = NSUserInterfaceItemIdentifier("toggle-info")
    static let togglePaneViewInspector = NSUserInterfaceItemIdentifier("toggle-inspector")
    static let togglePaneViewPreview = NSUserInterfaceItemIdentifier("toggle-preview")
    static let togglePaneViewTagList = NSUserInterfaceItemIdentifier("toggle-taglist")
}

class SidebarController: NSViewController {
    
    private enum PaneDividerIndex: Int {
        case info = 0
        case inspector
        case preview
        case taglist
         
        static var all: IndexSet {
            IndexSet([
                PaneDividerIndex.info.rawValue,
                PaneDividerIndex.inspector.rawValue,
                PaneDividerIndex.preview.rawValue,
                PaneDividerIndex.taglist.rawValue,
            ])
        }
    }
    
    internal weak var screenshot                 : Screenshot?
    
    @IBOutlet weak var splitView                 : NSSplitView!
    @IBOutlet weak var paneViewInfo              : NSView!
    @IBOutlet weak var paneViewInspector         : NSView!
    @IBOutlet weak var paneViewPreview           : NSView!
    @IBOutlet weak var paneViewTagList           : NSView!
    @IBOutlet weak var paneViewPlaceholder       : NSView!
    @IBOutlet weak var placeholderConstraint     : NSLayoutConstraint!

    private var paneViews                        : [NSView]              {
        [
            paneViewInfo,
            paneViewInspector,
            paneViewPreview,
            paneViewTagList,
            paneViewPlaceholder,
        ]
    }

    public var infoController                    : InfoController!       { children.first(where: { $0 is InfoController       }) as? InfoController       }
    public var inspectorController               : InspectorController!  { children.first(where: { $0 is InspectorController  }) as? InspectorController  }
    public var previewController                 : PreviewController!    { children.first(where: { $0 is PreviewController    }) as? PreviewController    }
    public var tagListController                 : TagListController!    { children.first(where: { $0 is TagListController    }) as? TagListController    }
    public var paneControllers                   : [PaneController]      {
        [
            infoController,
            inspectorController,
            previewController,
            tagListController,
        ]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        paneViews.forEach({ $0.translatesAutoresizingMaskIntoConstraints = false })

        NotificationCenter.default.addObserver(self, selector: #selector(applyPreferences(_:)), name: UserDefaults.didChangeNotification, object: nil)
        applyPreferences(nil)
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
    
    override func willPresentError(_ error: Error) -> Error {
        let error = super.willPresentError(error)
        debugPrint(error.localizedDescription)
        return error
    }
    
    
    // MARK: - Panes
    
    @IBOutlet var paneMenu: NSMenu!
    
    @objc private func applyPreferences(_ notification: Notification?) {
        updatePanesIfNeeded()
    }
    
    @IBAction func resetPanes(_ sender: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.resetPanes(sender)
    }
    
    @IBAction func togglePane(_ sender: NSMenuItem) {
        (NSApp.delegate as? AppDelegate)?.togglePane(sender)
    }
    
    private func updatePanesIfNeeded() {
        var paneChanged = false
        var hiddenValue: Bool!
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInformation]
        if paneViewInfo.isHidden != hiddenValue {
            paneViewInfo.isHidden = hiddenValue
            if !hiddenValue {
                infoController.reloadPane()
            }
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewInspector]
        if paneViewInspector.isHidden != hiddenValue {
            paneViewInspector.isHidden = hiddenValue
            if !hiddenValue {
                inspectorController.reloadPane()
            }
            paneChanged = true
        }
        
        hiddenValue = !UserDefaults.standard[.togglePaneViewPreview]
        if paneViewPreview.isHidden != hiddenValue {
            paneViewPreview.isHidden = hiddenValue
            if !hiddenValue {
                previewController.reloadPane()
            }
            paneChanged = true
        }

        hiddenValue = !UserDefaults.standard[.togglePaneViewTagList]
        if paneViewTagList.isHidden != hiddenValue {
            paneViewTagList.isHidden = hiddenValue
            if !hiddenValue {
                tagListController.reloadPane()
            }
            paneChanged = true
        }

        let resetValue: Bool = UserDefaults.standard[.resetPaneView]
        if resetValue {
            UserDefaults.standard[.resetPaneView] = false
            resetDividers()
        }
        
        placeholderConstraint.priority = hiddenValue ? .defaultLow : .defaultHigh

        if paneChanged {
            splitView.adjustSubviews()
            splitView.displayIfNeeded()
        }
    }
    
    @IBOutlet weak var dividerConstraintInfo       : NSLayoutConstraint!
    @IBOutlet weak var dividerConstraintInspector  : NSLayoutConstraint!
    @IBOutlet weak var dividerConstraintPreview    : NSLayoutConstraint!
    
    private func resetDividers(in set: IndexSet? = nil) {
        var dividerIndexes = set ?? PaneDividerIndex.all
        if paneViewInfo.isHidden {
            dividerIndexes.remove(PaneDividerIndex.info.rawValue)
        }
        if paneViewInspector.isHidden {
            dividerIndexes.remove(PaneDividerIndex.inspector.rawValue)
        }
        if paneViewPreview.isHidden {
            dividerIndexes.remove(PaneDividerIndex.preview.rawValue)
        }
        if paneViewTagList.isHidden {
            dividerIndexes.remove(PaneDividerIndex.taglist.rawValue)
        }
        if !dividerIndexes.isEmpty {
            splitView.adjustSubviews()
            dividerIndexes.forEach({ splitView.setPosition(splitView.maxPossiblePositionOfDivider(at: $0), ofDividerAt: $0) })
        }
    }
    
}

extension SidebarController: ScreenshotLoader {
    func load(_ screenshot: Screenshot) throws {
        self.screenshot = screenshot
        try paneControllers.forEach({ try $0.load(screenshot) })
        paneControllers.forEach({ $0.reloadPane() })

        resetDividers()
    }
}

extension SidebarController: PixelMatchResponder {
    func beginPixelMatchComparison(to image: PixelImage, with maskImage: JSTPixelImage, completionHandler: @escaping (Bool) -> Void) {
        infoController?.beginPixelMatchComparison(to: image, with: maskImage, completionHandler: completionHandler)
        resetDividers(in: IndexSet(integer: PaneDividerIndex.info.rawValue))
    }
    
    func endPixelMatchComparison() {
        infoController?.endPixelMatchComparison()
        resetDividers(in: IndexSet(integer: PaneDividerIndex.info.rawValue))
    }
}

extension SidebarController: NSMenuItemValidation, NSMenuDelegate {
    private var hasAttachedSheet: Bool { view.window?.attachedSheet != nil }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard !hasAttachedSheet else { return false }
        if menuItem.action == #selector(togglePane(_:)) || menuItem.action == #selector(resetPanes(_:)) {
            return true
        }
        guard screenshot != nil else { return false }
        return true
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu == paneMenu {
            menu.items.forEach { (menuItem) in
                if menuItem.identifier == .togglePaneViewInformation {
                    menuItem.state = UserDefaults.standard[.togglePaneViewInformation] ? .on : .off
                }
                else if menuItem.identifier == .togglePaneViewInspector {
                    menuItem.state = UserDefaults.standard[.togglePaneViewInspector] ? .on : .off
                }
                else if menuItem.identifier == .togglePaneViewPreview {
                    menuItem.state = UserDefaults.standard[.togglePaneViewPreview] ? .on : .off
                }
                else if menuItem.identifier == .togglePaneViewTagList {
                    menuItem.state = UserDefaults.standard[.togglePaneViewTagList] ? .on : .off
                }
            }
        }
    }
}

extension SidebarController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        guard dividerIndex < splitView.arrangedSubviews.count else { return proposedEffectiveRect }
        return splitView.arrangedSubviews[dividerIndex].isHidden ? .zero : proposedEffectiveRect
    }
    
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        guard dividerIndex < splitView.arrangedSubviews.count else { return false }
        return splitView.arrangedSubviews[dividerIndex].isHidden
    }
}

