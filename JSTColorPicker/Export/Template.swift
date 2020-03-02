//
//  Template.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/24/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import LuaSwift

extension String {
    
    // Modified from the DragonCherry extension - https://github.com/DragonCherry/VersionCompare
    private func compare(toVersion targetVersion: String) -> ComparisonResult {
        let versionDelimiter = "."
        var result: ComparisonResult = .orderedSame
        var versionComponents = components(separatedBy: versionDelimiter)
        var targetComponents = targetVersion.components(separatedBy: versionDelimiter)
        
        while versionComponents.count < targetComponents.count {
            versionComponents.append("0")
        }
        while targetComponents.count < versionComponents.count {
            targetComponents.append("0")
        }
        
        for (version, target) in zip(versionComponents, targetComponents) {
            result = version.compare(target, options: .numeric)
            if result != .orderedSame {
                break
            }
        }
        
        return result
    }
    
    func isVersion(equalTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedSame }
    func isVersion(greaterThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedDescending }
    func isVersion(greaterThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedAscending }
    func isVersion(lessThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedAscending }
    func isVersion(lessThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedDescending }
    
}

enum TemplateError: LocalizedError {
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
            return NSLocalizedString("This template requires JSTColorPicker (\(version)) or later.", comment: "TemplateError")
        case let .luaError(reason):
            return "\(reason)"
        case .missingRootEntry:
            return NSLocalizedString("Missing root entry: template must return a table.", comment: "TemplateError")
        case let .missingRequiredField(field):
            return NSLocalizedString("Missing required field: \(field).", comment: "TemplateError")
        case .missingReturnedString:
            return NSLocalizedString("Missing returned string.", comment: "TemplateError")
        case let .invalidField(field):
            return NSLocalizedString("Invalid field: \(field).", comment: "TemplateError")
        }
    }
}

class Template {
    
    public var url: URL
    public var uuid: UUID
    public var name: String
    public var version: String
    public var platformVersion: String
    public var author: String?
    public var description: String?
    public var allowedExtensions: [String] = []
    
    public static let currentPlatformVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private var generator: LuaSwift.Function
    private var vm = VirtualMachine(openLibs: true)
    
    init(from templateURL: URL) throws {
        self.url = templateURL
        switch vm.eval(templateURL, args: []) {
        case let .values(vals):
            guard let tab = vals.first as? Table else { throw TemplateError.missingRootEntry }
            let dict = tab.asDictionary({ $0 as String }, { $0 as String })
            
            guard let uuidString = dict["uuid"] else { throw TemplateError.missingRequiredField(field: "uuid") }
            guard let uuid = UUID(uuidString: uuidString) else { throw TemplateError.invalidField(field: "uuid") }
            guard let name = dict["name"] else { throw TemplateError.missingRequiredField(field: "name") }
            guard let version = dict["version"] else { throw TemplateError.missingRequiredField(field: "version") }
            
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
            guard let generator = generatorDict["generator"] else { throw TemplateError.missingRequiredField(field: "generator") }
            
            self.generator = generator
        case let .error(e):
            throw TemplateError.luaError(reason: e)
        }
    }
    
    public func generate(_ image: PixelImage, for items: [ContentItem]) throws -> String {
        switch generator.call([image] + items) {
        case let .values(vals):
            if let string = vals.first as? String {
                return string
            }
        case let .error(e):
            throw TemplateError.luaError(reason: e)
        }
        throw TemplateError.missingReturnedString
    }
    
}
