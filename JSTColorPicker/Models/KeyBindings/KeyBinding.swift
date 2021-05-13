//
//  KeyBinding.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2017-12-01.
//
//  ---------------------------------------------------------------------------
//
//  © 2017-2019 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

struct KeyBinding: Hashable, Codable {
    internal init(
        action: Selector,
        associatedIdentifier: String,
        associatedTag: Int,
        shortcut: Shortcut?
    ) {
        self.action = action
        self.associatedIdentifier = associatedIdentifier
        self.associatedTag = associatedTag
        self.shortcut = shortcut
    }
    
    let action: Selector
    let associatedIdentifier: String
    let associatedTag: Int
    let shortcut: Shortcut?
}

extension KeyBinding: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.action.description < rhs.action.description
    }
}

extension Selector: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = Selector(try container.decode(String.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(NSStringFromSelector(self))
    }
}
