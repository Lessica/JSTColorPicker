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
    
    public var url: URL
    public var uuid: UUID
    public var name: String
    public var version: String
    public var platformVersion: String
    public var author: String?
    public var description: String?
    public var allowedExtensions: [String] = []
    public var items: [[String: Any]] = []
    
    public static let currentPlatformVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private var generator: LuaSwift.Function
    private var vm = VirtualMachine(openLibs: true)
    
    init(from templateURL: URL) throws {
        self.url = templateURL
        switch vm.eval(templateURL, args: []) {
        case let .values(vals):
            guard let tab = vals.first as? Table else { throw Error.missingRootEntry }
            let dict = tab.asDictionary({ $0 as String }, { $0 as String })
            
            guard let uuidString = dict["uuid"]           else { throw Error.missingRequiredField(field: "uuid")    }
            guard let uuid = UUID(uuidString: uuidString) else { throw Error.invalidField(field: "uuid")            }
            guard let name = dict["name"]                 else { throw Error.missingRequiredField(field: "name")    }
            guard let version = dict["version"]           else { throw Error.missingRequiredField(field: "version") }
            
            self.uuid = uuid
            self.name = name
            self.version = version
            self.platformVersion = dict["platformVersion"] ?? Template.currentPlatformVersion
            self.author = dict["author"]
            self.description = dict["description"]
            if let ext = dict["extension"] {
                self.allowedExtensions.append(ext)
            }
            
            let generatorDict = tab.asDictionary({ $0 as String }, { $0 as LuaSwift.Function })
            guard let generator = generatorDict["generator"] else { throw Error.missingRequiredField(field: "generator") }
            
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
