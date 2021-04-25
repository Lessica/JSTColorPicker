//
//  DropSplitView.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension NSDraggingInfo {

    var draggedFileURLs: [URL]? {
        let paths = draggingPasteboard.propertyList(forType: .init(rawValue: "NSFilenamesPboardType")) as? [String]
        return paths?.compactMap({ URL(fileURLWithPath: $0) })
    }
    
}

@objc protocol DropViewDelegate: class {
    var allowsDrop: Bool { get }
    var acceptedFileExtensions: [String] { get }
    func dropView(_: DropSplitView?, didDropFilesWith fileURLs: [URL])
}

class DropSplitView: NSSplitView {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
    }
    
    private var fileTypeIsAllowed = false
    private var acceptedFileExtensions: [String] {
        return dropDelegate.acceptedFileExtensions
    }
    @IBOutlet weak var dropDelegate : DropViewDelegate!
    
    private func checkExtension(drag: NSDraggingInfo) -> Bool {
        guard let fileURLs = drag.draggedFileURLs else {
            return false
        }
        
        let fileExts = fileURLs.compactMap({ $0.pathExtension.lowercased() })
        guard fileURLs.count == fileExts.count else {
            return false
        }
        
        return fileExts.firstIndex(where: { !acceptedFileExtensions.contains($0) }) == nil
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !dropDelegate.allowsDrop {
            return []
        }
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
        guard let draggedFileURLs = sender.draggedFileURLs else {
            return false
        }
        
        dropDelegate.dropView(self, didDropFilesWith: draggedFileURLs)
        return true
    }
    
}
