//
//  TemplatePreviewObject.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/22.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

final class TemplatePreviewObject {
    enum State {
        case initialized
        case rejected
        case fulfilled
        case generating
        case configurating
    }
    
    let uuidString: String
    var contents: String?
    var error: String?
    var state: State = .initialized
    
    internal init(uuidString: String, contents: String?, error: String?) {
        self.uuidString = uuidString
        self.contents = contents
        self.error = error
        self.state = .initialized
    }
    
    var hasContents: Bool { !(contents?.isEmpty ?? true) }
    var hasError: Bool { !(error?.isEmpty ?? true) }
    var isPlaceholder: Bool { uuidString.isEmpty }
    
    static let placeholder = TemplatePreviewObject(uuidString: "", contents: nil, error: nil)
    
    func clear() {
        contents = nil
        error = nil
        state = .initialized
    }
}
