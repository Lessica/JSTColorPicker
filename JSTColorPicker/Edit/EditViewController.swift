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
    public var contentItem: ContentItem? {
        get { (view.window as? EditWindow)?.contentItem }
        set { (view.window as? EditWindow)?.contentItem = newValue }
    }
    public weak var contentDataSource: ContentDataSource? { (view.window as? EditWindow)?.contentDataSource }
    public weak var contentDelegate: ContentDelegate? { (view.window as? EditWindow)?.contentDelegate }
    
}
