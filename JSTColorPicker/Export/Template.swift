//
//  Template.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift


class Template {
    
    enum Error: LocalizedError {
        
        case unknown
        case unsatisfiedPlatformVersion(version: String)
        case luaError(reason: String)
        case missingRootEntry
        case missingRequiredField(field: String)
        case missingReturnedString
        case invalidField(field: String)
        
        var failureReason: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Internal error.", comment: "TemplateError")
            case let .unsatisfiedPlatformVersion(version):
                return String(format: NSLocalizedString("This template requires JSTColorPicker (%@) or later.", comment: "TemplateError"), version)
            case let .luaError(reason):
                return "\(reason)"
            case .missingRootEntry:
                return NSLocalizedString("Missing root entry: template must return a table.", comment: "TemplateError")
            case let .missingRequiredField(field):
                return String(format: NSLocalizedString("Missing required field: %@.", comment: "TemplateError"), field)
            case .missingReturnedString:
                return NSLocalizedString("Missing returned string.", comment: "TemplateError")
            case let .invalidField(field):
                return String(format: NSLocalizedString("Invalid field: %@.", comment: "TemplateError"), field)
            }
        }
        
    }
    
    public let url: URL
    public let uuid: UUID
    public let name: String
    public let version: String
    public let platformVersion: String
    public let author: String?
    public let description: String?
    public let allowedExtensions: [String]
    public let isAsync: Bool
    public let saveInPlace: Bool
    public let items: LuaSwift.Table?
    
    public static let currentPlatformVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private var generator: LuaSwift.Function
    private var vm = VirtualMachine(openLibs: true)
    
    init(from templateURL: URL) throws {
        self.url = templateURL
        switch vm.eval(templateURL, args: []) {
        case let .values(vals):
            guard let tab = vals.first as? Table else { throw Error.missingRootEntry }
            let stringDict = tab.asDictionary({ $0 as String }, { $0 as String })
            let boolDict = tab.asDictionary  ({ $0 as String }, { $0 as Bool   })
            
            guard let uuidString = stringDict["uuid"]           else { throw Error.missingRequiredField(field: "uuid")    }
            guard let uuid = UUID(uuidString: uuidString)       else { throw Error.invalidField(field: "uuid")            }
            guard let name = stringDict["name"]                 else { throw Error.missingRequiredField(field: "name")    }
            guard let version = stringDict["version"]           else { throw Error.missingRequiredField(field: "version") }
            
            self.uuid = uuid
            self.name = name
            self.version = version
            self.platformVersion = stringDict["platformVersion"] ?? Template.currentPlatformVersion
            self.author = stringDict["author"]
            self.description = stringDict["description"]
            if let ext = stringDict["extension"] {
                self.allowedExtensions = [ext]
            } else {
                self.allowedExtensions = []
            }
            if let async = boolDict["async"] {
                self.isAsync = async
            } else {
                self.isAsync = false
            }
            if let saveInPlace = boolDict["saveInPlace"] {
                self.saveInPlace = saveInPlace
            } else {
                self.saveInPlace = false
            }
            self.items = tab["items"] as? LuaSwift.Table
            
            guard let generator = tab["generator"] as? LuaSwift.Function else { throw Error.missingRequiredField(field: "generator") }
            
            self.generator = generator
        case let .error(e):
            throw Error.luaError(reason: e)
        }
    }
    
    public func generate(_ image: PixelImage, for items: [ContentItem]) throws -> String {
        switch generator.call([image] + items) {
        case let .values(vals):
            if let string = vals.first as? String {
                return string
            }
        case let .error(e):
            throw Error.luaError(reason: e)
        }
        throw Error.missingReturnedString
    }
    
}

protocol TemplateItem {
    var type: TemplateItemType { get }
    var label: String { get }
    var key: String { get }
}

enum TemplateItemType: String {
    case option, toggle, integer, number, text
}

extension Template {
    
    // MARK: - Items
    
    struct OptionItem: TemplateItem {
        let type: TemplateItemType = .option
        let label: String
        let key: String
        let value: String
        let options: [String]
    }
    
    struct ToggleItem: TemplateItem {
        let type: TemplateItemType = .toggle
        let label: String
        let key: String
        let value: Bool
    }
    
    struct IntegerItem: TemplateItem {
        let type: TemplateItemType = .integer
        let label: String
        let key: String
        let value: Int64
    }
    
    struct NumberItem: TemplateItem {
        let type: TemplateItemType = .number
        let label: String
        let key: String
        let value: Double
    }
    
    struct TextItem: TemplateItem {
        let type: TemplateItemType = .text
        let label: String
        let key: String
        let value: String
    }
    
    public func parseItems() throws -> [TemplateItem]? {
        
        guard let items = items else { return nil }
        
        var retItems = [TemplateItem]()
        var itemIdx = 1
        let itemTabArr: [LuaSwift.Table] = items.asSequence()
        
        for itemTab in itemTabArr {
            
            guard let itemTypeStr = itemTab["type"] as? String else {
                throw Error.missingRequiredField(field: "items[\(itemIdx)].type")
            }
            
            guard let itemType = TemplateItemType(rawValue: itemTypeStr) else {
                throw Error.invalidField(field: "items[\(itemIdx)].type")
            }
            
            guard let itemLabelStr = itemTab["label"] as? String else {
                throw Error.missingRequiredField(field: "items[\(itemIdx)].label")
            }
            
            guard let itemKeyStr = itemTab["key"] as? String else {
                throw Error.missingRequiredField(field: "items[\(itemIdx)].key")
            }
            
            var retItem: TemplateItem
            switch itemType {
            case .option:
                
                guard let itemValue = itemTab["value"] as? String else {
                    throw Error.invalidField(field: "items[\(itemIdx)].value")
                }
                
                guard let itemOptionTab = itemTab["options"] as? LuaSwift.Table else {
                    throw Error.invalidField(field: "items[\(itemIdx)].options")
                }
                
                let itemOptions: [String] = itemOptionTab.asSequence()
                retItem = OptionItem(label: itemLabelStr, key: itemKeyStr, value: itemValue, options: itemOptions)
                
            case .toggle:
                
                guard let itemValue = itemTab["value"] as? Bool else {
                    throw Error.invalidField(field: "items[\(itemIdx)].value")
                }
                
                retItem = ToggleItem(label: itemLabelStr, key: itemKeyStr, value: itemValue)
                
            case .integer:
                
                guard let itemValue = itemTab["value"] as? Int64 else {
                    throw Error.invalidField(field: "items[\(itemIdx)].value")
                }
                
                retItem = IntegerItem(label: itemLabelStr, key: itemKeyStr, value: itemValue)
                
            case .number:
                
                guard let itemValue = itemTab["value"] as? Double else {
                    throw Error.invalidField(field: "items[\(itemIdx)].value")
                }
                
                retItem = NumberItem(label: itemLabelStr, key: itemKeyStr, value: itemValue)
                
            case .text:
                
                guard let itemValue = itemTab["value"] as? String else {
                    throw Error.invalidField(field: "items[\(itemIdx)].value")
                }
                
                retItem = TextItem(label: itemLabelStr, key: itemKeyStr, value: itemValue)
                
            }
            
            retItems.append(retItem)
            itemIdx += 1
            
        }
        
        return retItems
        
    }
    
}
