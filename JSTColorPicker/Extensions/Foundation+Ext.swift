//
//  Foundation+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension String {
    func leftPadding(to length: Int, with character: Character) -> String {
        if length <= self.count {
            return String(self)
        }
        let newLength = self.count
        if newLength < length {
            return String(repeatElement(character, count: length - newLength)) + self
        } else {
            let idx = self.index(self.startIndex, offsetBy: newLength - length)
            return String(self[..<idx])
        }
    }
}
