//
//  Template.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

final class Template {
    
    enum Error: CustomNSError, LocalizedError {
        
        case unknown
        case unsatisfiedPlatformVersion(version: String)
        case luaError(reason: String)
        
        case missingRootEntry
        case missingRequiredField(field: String)
        
        case missingReturnedString
        case invalidResultType(type: String, allowedValues: [String])
        case invalidResultArgumentCount(type: String, count: Int, expectedCount: Int)
        case invalidResultArgumentType(type: String, index: Int, argType: String, expectedType: String)
        
        case resourceBusy
        case invalidField(field: String)
        
        var errorCode: Int {
            switch self {
                case .unknown:
                    return 502
                case .unsatisfiedPlatformVersion(_):
                    return 503
                case .luaError(_):
                    return 504
                    
                case .missingRootEntry:
                    return 505
                case .missingRequiredField(_):
                    return 506
                    
                case .missingReturnedString:
                    return 507
                case .invalidResultType(_, _):
                    return 508
                case .invalidResultArgumentCount(_, _, _):
                    return 509
                case .invalidResultArgumentType(_, _, _, _):
                    return 510
                    
                case .resourceBusy:
                    return 511
                case .invalidField(_):
                    return 512
            }
        }
        
        var failureReason: String? {
            switch self {
                case .unknown:
                    return NSLocalizedString("Internal error.", comment: "Template.Error")
                case let .unsatisfiedPlatformVersion(version):
                    return String(format: NSLocalizedString("This template requires JSTColorPicker (%@) or later.", comment: "Template.Error"), version)
                case let .luaError(reason):
                    return "\(reason)"
                    
                case .missingRootEntry:
                    return NSLocalizedString("Missing root entry: template must return a table.", comment: "Template.Error")
                case let .missingRequiredField(field):
                    return String(format: NSLocalizedString("Missing required field “%@”.", comment: "Template.Error"), field)
                    
                case .missingReturnedString:
                    return NSLocalizedString(
                        "Missing returned string: the first returned value must be a string.", comment: "Template.Error")
                case let .invalidResultType(type, allowedValues):
                    return String(format: NSLocalizedString(
                        "Invalid result type “%@”, allowed types are: %@.", comment: "Template.Error"), type, allowedValues.joined(separator: ", "))
                case let .invalidResultArgumentCount(type, count, expectedCount):
                    return String(format: NSLocalizedString(
                        "Unexpected argument count for result type “%@”, expected %ld, got %ld.", comment: "Template.Error"), type, expectedCount, count)
                case let .invalidResultArgumentType(type, index, argType, expectedType):
                    return String(format: NSLocalizedString(
                        "Unexpected argument #%ld type for result type “%@”, expected “%@”, got “%@”.", comment: "Template.Error"), index, type, expectedType, argType)
                    
                case .resourceBusy:
                    return NSLocalizedString("Resource busy.", comment: "Template.Error")
                case let .invalidField(field):
                    return String(format: NSLocalizedString("Invalid field “%@”.", comment: "Template.Error"), field)
            }
        }
    }
    
    enum GenerateAction: String, LuaSwift.Value {
        
        case preview
        case copy
        case doubleCopy
        case export
        case exportInPlace
        
        func push(_ vm: VirtualMachine) {
            rawValue.push(vm)
        }
        
        func kind() -> Kind {
            return rawValue.kind()
        }
        
        static func arg(_ vm: VirtualMachine, value: Value) -> String? {
            return String.arg(vm, value: value)
        }
        
        var isInteractive: Bool {
            switch self {
            case .preview:
                return false
            case .copy, .doubleCopy, .export, .exportInPlace:
                return true
            }
        }
    }
    
    enum GenerateResult {
        case plain(text: String)
        case markdown(text: String)
        case alert(title: String, message: String? = nil)
        case document(url: URL)
        case comparison(url: URL)
    }
    
                 let url                  : URL
    private(set) var uuid                 : UUID
    private(set) var name                 : String
    private(set) var version              : String
    private(set) var platformVersion      : String
    private(set) var author               : String?
    private(set) var userDescription      : String?
    private(set) var userExtension        : String?
    private(set) var allowedExtensions    : [String]

    private(set) var isAsync              : Bool
    private(set) var isEnabled            : Bool
    private(set) var isPreviewable        : Bool
    private(set) var saveInPlace          : Bool

    private(set) var items                : LuaSwift.Table?
    private      var generator            : LuaSwift.Function
    private      var mutexLock            = NSLock()
    private      var contentModification  : Date?

    private      let vm                   : VirtualMachine
    weak         var manager              : TemplateManager?
    
    static let currentPlatformVersion     = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    
    init(templateURL url: URL, templateManager manager: TemplateManager?) throws {
        self.url = url
        self.manager = manager

        self.contentModification = url.contentModification
        
        let vm = VirtualMachine(openLibs: true)
        vm.globals["applicationSupportDirectory"] = AppDelegate.supportDirectoryURL.path
        
        self.vm = vm
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
                self.userExtension = ext
                self.allowedExtensions = [ext]
            } else {
                self.userExtension = nil
                self.allowedExtensions = []
            }

            if let async = boolDict["async"] {
                self.isAsync = async
            } else {
                self.isAsync = false
            }

            if let enabled = boolDict["enabled"] {
                self.isEnabled = enabled
            } else {
                self.isEnabled = true
            }

            if let previewable = boolDict["previewable"] {
                self.isPreviewable = previewable
            } else {
                self.isPreviewable = false
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

    deinit {
        debugPrint("\(String(describing: Self.self)):\(#function)")
    }
    
    func generate(_ image: PixelImage, _ items: [ContentItem], forAction action: GenerateAction) throws -> GenerateResult
    {
        guard mutexLock.try() else {
            throw Error.resourceBusy
        }
        
        let execContent = Content(items: items)
        let results = generator.call([
            image,
            execContent,
            action,
        ])
        
        mutexLock.unlock()
        
        switch results {
        case let .values(vals):
            if vals.count > 0, let retType = vals.first as? String {
                if vals.count == 1 {
                    return .plain(text: retType)  // as plain text
                }
                else {
                    if retType == "text" || retType == "plain" || retType == "markdown" {
                        if vals.count == 2 {
                            let retVal = vals.last!
                            if let retVal = retVal as? String {
                                if retType == "markdown" {
                                    return .markdown(text: retVal)
                                }
                                return .plain(text: retVal)
                            } else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 1,
                                    argType: String(describing: retVal.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                        }
                        else {
                            throw Error.invalidResultArgumentCount(
                                type: retType.truncated(limit: 20),
                                count: vals.count,
                                expectedCount: 2
                            )
                        }
                    }
                    else if retType == "document" {
                        if vals.count == 2 {
                            let retVal = vals.last!
                            if let retVal = retVal as? String {
                                return .document(url: URL(fileURLWithPath: retVal))
                            } else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 1,
                                    argType: String(describing: retVal.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                        }
                        else {
                            throw Error.invalidResultArgumentCount(
                                type: retType.truncated(limit: 20), count: vals.count, expectedCount: 2)
                        }
                    }
                    else if retType == "comparison" {
                        if vals.count == 2 {
                            let retVal = vals.last!
                            if let retVal = retVal as? String {
                                return .comparison(url: URL(fileURLWithPath: retVal))
                            } else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 1,
                                    argType: String(describing: retVal.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                        }
                        else {
                            throw Error.invalidResultArgumentCount(
                                type: retType.truncated(limit: 20),
                                count: vals.count,
                                expectedCount: 2
                            )
                        }
                    }
                    else if retType == "alert" || retType == "prompt" {
                        if vals.count == 2 {
                            let retVal = vals.last!
                            if let retVal = retVal as? String {
                                return .alert(title: retVal)
                            } else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 1,
                                    argType: String(describing: retVal.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                        }
                        else if vals.count == 3 {
                            let retValTitle = vals[1]
                            guard let retValTitle = retValTitle as? String else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 1,
                                    argType: String(describing: retValTitle.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                            let retValMessage = vals[2]
                            guard let retValMessage = retValMessage as? String else {
                                throw Error.invalidResultArgumentType(
                                    type: retType.truncated(limit: 20),
                                    index: 2,
                                    argType: String(describing: retValMessage.kind().self),
                                    expectedType: Kind.string.rawValue
                                )
                            }
                            return .alert(title: retValTitle, message: retValMessage)
                        }
                        else {
                            throw Error.invalidResultArgumentCount(
                                type: retType.truncated(limit: 20),
                                count: vals.count,
                                expectedCount: 3
                            )
                        }
                    }
                    else {
                        throw Error.invalidResultType(
                            type: retType.truncated(limit: 20),
                            allowedValues: [
                                "text",
                                "document",
                                "comparison",
                                "prompt",
                            ]
                        )
                    }
                }
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
