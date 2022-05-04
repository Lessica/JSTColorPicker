//
//  MainMenu.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2016-10-19.
//
//  ---------------------------------------------------------------------------
//
//  © 2016-2020 1024jp
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

import AppKit

enum MainMenu: Int {
    case application
    case file
    case edit
    case view
    case scene
    case annotation
    case devices
    case tags
    case templates
    case window
    case help
    
    enum MenuItemTag: Int {
        case services = 999
        case sharingService = 1999
        case recentDocumentsDirectory = 2999
        case devices = 6999
        case tags = 7999
        case tagDefinitions = 8999
        case templates = 9999
    }
    
    var menu: NSMenu? {
        return NSApp.mainMenu?.item(at: self.rawValue)?.submenu
    }
}
