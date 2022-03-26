//
//  EditViewController.swift
//  JSTColorPicker
//
//  Created by Apple on 2020/6/5.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class EditViewController: NSViewController {
    
    var editWindow: EditWindow? { view.window as? EditWindow }
    var isAdd: Bool { editWindow?.isAdd ?? true }

    var image: PixelImage? { editWindow?.loader?.screenshot?.image }
    var contentItem: ContentItem? {
        get { editWindow?.contentItem }
        set { editWindow?.contentItem = newValue }
    }

    var contentItems: [ContentItem]? { editWindow?.contentItems }

    var contentItemSource: ContentItemSource? { editWindow?.contentItemSource }
    var contentDelegate: ContentActionResponder? { editWindow?.contentDelegate }
    var tagManager: TagListSource? { editWindow?.tagManager }

    var undoToken: NotificationToken?
    var redoToken: NotificationToken?
}

extension EditViewController: NSTextFieldDelegate { }
