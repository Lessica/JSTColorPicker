//
//  DraggedTag.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/3/24.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

struct DraggedTag {
    internal init(row: Int, name: String, defaultUserInfo: [String : String]) {
        self.row = row
        self.name = name
        self.defaultUserInfo = defaultUserInfo
    }
    
    internal init(dictionary: [String: Any]) {
        self.row = dictionary["row"] as! Int
        self.name = dictionary["name"] as! String
        self.defaultUserInfo = dictionary["defaultUserInfo"] as! [String: String]
    }
    
    let row: Int
    let name: String
    let defaultUserInfo: [String: String]
    
    var dictionary: [String: Any] {
        [
            "row": row,
            "name": name,
            "defaultUserInfo": defaultUserInfo
        ]
    }
}
