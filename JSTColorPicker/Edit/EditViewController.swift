//
//  EditViewController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class EditViewController: NSViewController {
    
    public var isAdd: Bool { (view.window as? EditWindow)?.isAdd ?? true }
    
    public var image: PixelImage? { (view.window as? EditWindow)?.loader?.screenshot?.image }
    public var contentItem: ContentItem? {
        get { (view.window as? EditWindow)?.contentItem            }
        set { (view.window as? EditWindow)?.contentItem = newValue }
    }
    public var contentItems: [ContentItem]? { (view.window as? EditWindow)?.contentItems }
    
    public weak var contentItemSource: ContentItemSource? { (view.window as? EditWindow)?.contentItemSource }
    public weak var contentDelegate: ContentDelegate?     { (view.window as? EditWindow)?.contentDelegate   }
    
    internal var undoToken: NotificationToken?
    internal var redoToken: NotificationToken?
    
}

extension EditViewController: NSTextFieldDelegate { }

