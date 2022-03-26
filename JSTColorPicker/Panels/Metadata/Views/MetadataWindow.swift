//
//  MetadataWindow.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/3/26.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa

final class MetadataWindow: NSWindow {
    
    static var storyboard = NSStoryboard(name: "Metadata", bundle: nil)
    weak var loader: ScreenshotLoader?
    
    static func newMetadataPanel() -> MetadataWindow {
        return (storyboard.instantiateInitialController() as! MetadataWindowController).window as! MetadataWindow
    }
}
