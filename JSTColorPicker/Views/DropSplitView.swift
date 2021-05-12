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
        let paths = draggingPasteboard.propertyList(
            forType: .init(rawValue: "NSFilenamesPboardType")
        ) as? [String]
        return paths?.compactMap({ URL(fileURLWithPath: $0) })
    }
    
}

@objc protocol DropViewDelegate: AnyObject {
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
    
    private func checkExtension(_ sender: NSDraggingInfo) -> Bool {
        guard let draggedFileURLs = sender.draggedFileURLs else {
            return false
        }
        
        return draggedFileURLs
            .filter({ $0.isRegularFile })
            .firstIndex(
                where: {
                    acceptedFileExtensions.contains($0.pathExtension)
                }
            ) != nil
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !dropDelegate.allowsDrop {
            return []
        }
        if checkExtension(sender) {
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
        
        dropDelegate.dropView(
            self,
            didDropFilesWith: draggedFileURLs
                .filter({ $0.isRegularFile && acceptedFileExtensions.contains($0.pathExtension) })
        )
        return true
    }
    
}
