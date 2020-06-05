//
//  EditWindow.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditWindow: NSWindow {
    
    public static func newEditCoordinatePanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditCoordinateWindowController") as! NSWindowController).window as! EditWindow
    }
    
    public static func newEditAreaPanel() -> EditWindow {
        return (NSStoryboard(name: "Edit", bundle: nil).instantiateController(withIdentifier: "EditAreaWindowController") as! NSWindowController).window as! EditWindow
    }
    
    public var contentItem: ContentItem?
    public weak var contentDelegate: ContentDelegate?
    public weak var contentDataSource: ContentDataSource?

}
