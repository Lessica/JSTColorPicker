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
        get { (view.window as? EditWindow)?.contentItem }
        set { (view.window as? EditWindow)?.contentItem = newValue }
    }

    var contentItems: [ContentItem]? { (view.window as? EditWindow)?.contentItems }

    var contentItemSource: ContentItemSource? { (view.window as? EditWindow)?.contentItemSource }
    var contentDelegate: ContentActionResponder? { (view.window as? EditWindow)?.contentDelegate }
    var tagManager: TagListSource? { (view.window as? EditWindow)?.tagManager }

    var undoToken: NotificationToken?
    var redoToken: NotificationToken?
}

extension EditViewController: NSTextFieldDelegate { }
