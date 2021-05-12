//
//  EditViewController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa


class EditViewController: NSViewController {
    var isAdd: Bool { (view.window as? EditWindow)?.isAdd ?? true }
    
    var image: PixelImage? { (view.window as? EditWindow)?.loader?.screenshot?.image }
    var contentItem: ContentItem? {
        get { (view.window as? EditWindow)?.contentItem            }
        set { (view.window as? EditWindow)?.contentItem = newValue }
    }
    var contentItems: [ContentItem]? { (view.window as? EditWindow)?.contentItems }
    
    weak var contentItemSource: ContentItemSource? { (view.window as? EditWindow)?.contentItemSource }
    weak var contentDelegate: ContentActionResponder?     { (view.window as? EditWindow)?.contentDelegate   }
    
    var undoToken: NotificationToken?
    var redoToken: NotificationToken?
}

extension EditViewController: NSTextFieldDelegate { }

