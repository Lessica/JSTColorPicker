//
//  ExportPanelAccessoryView.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/30.
//  Copyright © 2021 JST. All rights reserved.
//

import Cocoa

final class ExportPanelAccessoryView: NSView {
    private static let nibName = String(describing: ExportPanelAccessoryView.self)
    @IBOutlet weak var locateAfterOperationButton: NSButton!
    
    var locateAfterOperation: Bool { locateAfterOperationButton.state == .on }
    
    static func instantiateFromNib(withOwner owner: Any?) -> ExportPanelAccessoryView? {
        var views: NSArray?
        guard NSNib(nibNamed: nibName, bundle: Bundle(for: Self.self))!.instantiate(withOwner: owner, topLevelObjects: &views)
        else { return nil }
        return views?.compactMap({ $0 as? ExportPanelAccessoryView }).first
    }
}
