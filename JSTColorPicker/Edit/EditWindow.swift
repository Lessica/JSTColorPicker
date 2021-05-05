//
//  EditWindow.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class EditWindow: NSWindow {
    
    enum EditType {
        case add
        case edit
    }
    
    static func newEditCoordinatePanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditCoordinateWindowController") as! NSWindowController).window as! EditWindow
    }
    
    static func newEditAreaPanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditAreaWindowController") as! NSWindowController).window as! EditWindow
    }
    
    static func newEditTagsPanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditTagsWindowController") as! NSWindowController).window as! EditWindow
    }
    
    var isAdd: Bool { type == .add }
    var type: EditType = .add
    var contentItem: ContentItem?
    var contentItems: [ContentItem]?
    
    weak var loader: ScreenshotLoader?
    weak var contentDelegate: ContentActionResponder?
    weak var contentItemSource: ContentItemSource?

}

