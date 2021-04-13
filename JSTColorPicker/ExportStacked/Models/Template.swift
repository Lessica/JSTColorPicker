//
//  Template.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension URL {
    /// The time at which the resource was created.
    /// This key corresponds to an Date value, or nil if the volume doesn't support creation dates.
    /// A resource’s creationDateKey value should be less than or equal to the resource’s contentModificationDateKey and contentAccessDateKey values. Otherwise, the file system may change the creationDateKey to the lesser of those values.
    var creation: Date? {
        get {
            return (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
        }
        set {
            var resourceValues = URLResourceValues()
            resourceValues.creationDate = newValue
            try? setResourceValues(resourceValues)
        }
    }
    /// The time at which the resource was most recently modified.
    /// This key corresponds to an Date value, or nil if the volume doesn't support modification dates.
    var contentModification: Date? {
        get {
            return (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
        set {
            var resourceValues = URLResourceValues()
            resourceValues.contentModificationDate = newValue
            try? setResourceValues(resourceValues)
        }
    }
    /// The time at which the resource was most recently accessed.
    /// This key corresponds to an Date value, or nil if the volume doesn't support access dates.
    ///  When you set the contentAccessDateKey for a resource, also set contentModificationDateKey in the same call to the setResourceValues(_:) method. Otherwise, the file system may set the contentAccessDateKey value to the current contentModificationDateKey value.
    var contentAccess: Date? {
        get {
            return (try? resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
        }
        // Beginning in macOS 10.13, iOS 11, watchOS 4, tvOS 11, and later, contentAccessDateKey is read-write. Attempts to set a value for this file resource property on earlier systems are ignored.
        set {
            var resourceValues = URLResourceValues()
            resourceValues.contentAccessDate = newValue
            try? setResourceValues(resourceValues)
        }
    }
}

class Template: NSObject, NSFilePresenter {
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

    var presentedItemURL: URL? { url }
    var presentedItemOperationQueue: OperationQueue = .main

    func presentedItemDidChange() {
        guard let oldModification = contentModification,
              let newModification = url.contentModification
        else { return }

        guard oldModification.distance(to: newModification) > 0 else {
            return
        }
        debugPrint("<\(debugDescription) changed>")

        do {
            switch self.vm.eval(url, args: []) {
            case let .values(vals):
                guard let tab = vals.first as? Table else { throw Error.missingRootEntry }
                let stringDict = tab.asDictionary({ $0 as String }, { $0 as String })
                let boolDict = tab.asDictionary  ({ $0 as String }, { $0 as Bool   })

                guard let uuidString = stringDict["uuid"]           else { throw Error.missingRequiredField(field: "uuid")    }
                guard let uuid = UUID(uuidString: uuidString)       else { throw Error.invalidField        (field: "uuid")    }
                guard let name = stringDict["name"]                 else { throw Error.missingRequiredField(field: "name")    }
                guard let version = stringDict["version"]           else { throw Error.missingRequiredField(field: "version") }

                self.uuid = uuid
                self.name = name
                self.version = version
                self.platformVersion = stringDict["platformVersion"] ?? Template.currentPlatformVersion
                self.author = stringDict["author"]
                self.userDescription = stringDict["description"]
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
                
                self.contentModification = newModification
            case let .error(e):
                throw Error.luaError(reason: e)
            }
        } catch let error as LocalizedError {
            manager?.redirectTemplateError(error, templateURL: url)
        } catch { }
    }
    
                 let url                  : URL
    private(set) var uuid                 : UUID
    private(set) var name                 : String
    private(set) var version              : String
    private(set) var platformVersion      : String
    private(set) var author               : String?
    private(set) var userDescription      : String?
    private(set) var allowedExtensions    : [String]
    private(set) var isAsync              : Bool
    private(set) var saveInPlace          : Bool
    private(set) var items                : LuaSwift.Table?
    private      var generator            : LuaSwift.Function
    private      var contentModification  : Date?

    private      let vm                   : VirtualMachine
    weak         var manager              : TemplateManager?
    
    static let currentPlatformVersion     = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    
    init(templateURL url: URL, templateManager manager: TemplateManager?) throws {
        self.url = url
        self.manager = manager

        self.contentModification = url.contentModification
        self.vm = VirtualMachine(openLibs: true)

        switch self.vm.eval(url, args: []) {
        case let .values(vals):
            guard let tab = vals.first as? Table else { throw Error.missingRootEntry }
            let stringDict = tab.asDictionary({ $0 as String }, { $0 as String })
            let boolDict = tab.asDictionary  ({ $0 as String }, { $0 as Bool   })
            
            guard let uuidString = stringDict["uuid"]      else { throw Error.missingRequiredField(field: "uuid")    }
            guard let uuid = UUID(uuidString: uuidString)  else { throw Error.invalidField        (field: "uuid")    }
            guard let name = stringDict["name"]            else { throw Error.missingRequiredField(field: "name")    }
            guard let version = stringDict["version"]      else { throw Error.missingRequiredField(field: "version") }
            
            self.uuid = uuid
            self.name = name
            self.version = version
            self.platformVersion = stringDict["platformVersion"] ?? Template.currentPlatformVersion
            self.author = stringDict["author"]
            self.userDescription = stringDict["description"]
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

        super.init()
    }

    deinit {
        debugPrint("<\(debugDescription) deinit>")
    }
    
    func generate(_ image: PixelImage, for items: [ContentItem]) throws -> String {
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
    
    func parseItems() throws -> [TemplateItem]? {
        
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
