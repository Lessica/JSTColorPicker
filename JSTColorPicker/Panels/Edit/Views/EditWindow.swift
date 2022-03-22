//
//  EditWindow.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


final class EditWindow: NSWindow {
    
    enum EditType {
        case add
        case edit
    }
    
    static var storyboard = NSStoryboard(name: "Edit", bundle: nil)
    
    static func newEditCoordinatePanel() -> EditWindow {
        return (storyboard.instantiateController(withIdentifier: "EditCoordinateWindowController") as! NSWindowController).window as! EditWindow
    }
    
    static func newEditAreaPanel() -> EditWindow {
        return (storyboard.instantiateController(withIdentifier: "EditAreaWindowController") as! NSWindowController).window as! EditWindow
    }
    
    static func newEditTagsPanel() -> EditWindow {
        return (storyboard.instantiateController(withIdentifier: "EditTagsWindowController") as! NSWindowController).window as! EditWindow
    }
    
    static func newEditAssociatedValuesPanel() -> EditWindow {
        return (storyboard.instantiateController(withIdentifier: "EditAssociatedValuesWindowController") as! NSWindowController).window as! EditWindow
    }
    
    var isAdd: Bool { type == .add }
    var type: EditType = .add
    var contentItem: ContentItem?
    var contentItems: [ContentItem]?
    
    weak var loader: ScreenshotLoader?
    weak var contentDelegate: ContentActionResponder?
    weak var contentItemSource: ContentItemSource?
    weak var tagManager: TagListSource?

}

