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
//  © 2017-2022 1024jp
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

import struct Foundation.Selector

struct KeyBinding: Hashable, Codable {
    
    let name: String
    let associatedIdentifier: String
    let associatedTag: Int
    let action: Selector
    let shortcut: Shortcut?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(associatedIdentifier)
        hasher.combine(associatedTag)
        hasher.combine(action)
        hasher.combine(shortcut)
    }
}


extension KeyBinding: Comparable {
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.action.description < rhs.action.description
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.associatedIdentifier == rhs.associatedIdentifier
        && lhs.associatedTag == rhs.associatedTag
        && lhs.action.description == rhs.action.description
        && lhs.shortcut == rhs.shortcut
    }
}
