//
//  ScreenshotController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

class ScreenshotController: NSDocumentController {
    
    override var documentClassNames: [String] {
        return ["Screenshot"]
    }
    
    override func documentClass(forType typeName: String) -> AnyClass? {
        return Screenshot.self
    }
    
    override var hasEditedDocuments: Bool {
        return false
    }
    
}
