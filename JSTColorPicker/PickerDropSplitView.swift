//
//  PickerDropSplitView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

@objc protocol DropViewDelegate {
    var acceptedFileExtensions: [String] { get }
    func dropView(_: PickerDropSplitView?, didDropFileWith fileURL: NSURL)
}

class PickerDropSplitView: NSSplitView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
    }
    
    private var fileTypeIsAllowed = false
    private var acceptedFileExtensions: [String] {
        return dropDelegate?.acceptedFileExtensions ?? []
    }
    @IBOutlet var dropDelegate : DropViewDelegate?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    func checkExtension(drag: NSDraggingInfo) -> Bool {
        guard let fileExt = drag.draggedFileURL?.pathExtension?.lowercased() else {
            return false
        }
        
        return acceptedFileExtensions.contains(fileExt)
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if checkExtension(drag: sender) {
            fileTypeIsAllowed = true
            return .copy
        } else {
            fileTypeIsAllowed = false
            return []
        }
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if fileTypeIsAllowed {
            return .copy
        } else {
            return []
        }
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let draggedFileURL = sender.draggedFileURL else {
            return false
        }
        
        dropDelegate?.dropView(self, didDropFileWith: draggedFileURL)
        return true
    }
    
}

extension NSDraggingInfo {
    var draggedFileURL: NSURL? {
        let filenames = draggingPasteboard.propertyList(forType: .init(rawValue: "NSFilenamesPboardType")) as? [String]
        let path = filenames?.first
        return path.map(NSURL.init)
    }
}
