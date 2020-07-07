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
    
    public static func newEditCoordinatePanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditCoordinateWindowController") as! NSWindowController).window as! EditWindow
    }
    
    public static func newEditAreaPanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditAreaWindowController") as! NSWindowController).window as! EditWindow
    }
    
    public static func newEditTagsPanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditTagsWindowController") as! NSWindowController).window as! EditWindow
    }
    
    public var isAdd: Bool { type == .add }
    public var type: EditType = .add
    public var contentItem: ContentItem?
    public var contentItems: [ContentItem]?
    
    public weak var loader: ScreenshotLoader?
    public weak var contentDelegate: ContentDelegate?
    public weak var contentItemSource: ContentItemSource?

}

