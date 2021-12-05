//
//  TemplateManager.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/13/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import OSLog

@objc final class TemplateManager: NSObject {
    enum Error: LocalizedError {
        case unknown
        case resourceBusy

        var failureReason: String? {
            switch self {
            case .unknown:
                return NSLocalizedString("Internal error.", comment: "TemplateManager.Error")
            case .resourceBusy:
                return NSLocalizedString("Resource busy.", comment: "TemplateManager.Error")
            }
        }
    }

    static var shared = TemplateManager()

    struct NotificationType {
        struct Name {
            static let templatesWillLoadNotification         = NSNotification.Name(rawValue: "TemplateManager.templatesWillLoadNotification")
            static let templatesDidLoadNotification          = NSNotification.Name(rawValue: "TemplateManager.templatesDidLoadNotification")
            static let templateManagerDidLockNotification    = NSNotification.Name(rawValue: "TemplateManager.templateManagerDidLockNotification")
            static let templateManagerDidUnlockNotification  = NSNotification.Name(rawValue: "TemplateManager.templateManagerDidUnlockNotification")
            static let selectedTemplateDidChangeNotification = NSNotification.Name(rawValue: "TemplateManager.selectedTemplateDidChangeNotification")
        }
        struct Key {
            static let template = "template"
            static let templateUUID = "uuid"
        }
    }

    static var templateRootURL: URL {
        let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )
        .first!
        .appendingPathComponent(Bundle.main.bundleIdentifier!)
        .appendingPathComponent("templates")

        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return url
    }

    static var exampleTemplateURLs: [URL] = {
        return [
            Bundle.main.url(forResource: "ExampleTemplates", withExtension: "bundle")!,
        ]
    }()

    private      var _lockedCount          : Int = 0
    private      var lockedCount           : Int {
        get {
            _lockedCount
        }
        set {
            let origVal = _lockedCount
            _lockedCount = newValue
            if origVal == 0 && newValue > 0 {
                NotificationCenter.default.post(name: NotificationType.Name.templateManagerDidLockNotification, object: self)
            } else if origVal > 0 && newValue == 0 {
                NotificationCenter.default.post(name: NotificationType.Name.templateManagerDidUnlockNotification, object: self)
            }
        }
    }

                 var isLocked              : Bool { _lockedCount > 0 }
    private(set) var templates             : [Template] = []
    private(set) var enabledTemplates      : [Template] = []
    private(set) var previewableTemplates  : [Template] = []
    private      var templateMappings      : [String: Template]?

    func templateWithUUIDString(_ uuidString: String) -> Template? {
        guard let mappings = templateMappings else { return nil }
        return mappings[uuidString]
    }

    var numberOfTemplates: Int { templates.count }
    var numberOfEnabledTemplates: Int { enabledTemplates.count }
    var numberOfPreviewableTemplates: Int { previewableTemplates.count }

    var selectedTemplate: Template? {
        get { templates.first(where: { $0.uuid.uuidString == selectedTemplateUUID?.uuidString }) }
        set {
            selectedTemplateUUID = newValue?.uuid
            if let template = newValue {
                NotificationCenter.default.post(
                    name: NotificationType.Name.selectedTemplateDidChangeNotification,
                    object: nil,
                    userInfo: [
                        NotificationType.Key.template: template,
                        NotificationType.Key.templateUUID: template.uuid,
                    ]
                )
            } else {
                NotificationCenter.default.post(
                    name: NotificationType.Name.selectedTemplateDidChangeNotification,
                    object: nil
                )
            }
        }
    }

    private(set) var selectedTemplateUUID: UUID? {
        get { UUID(uuidString: UserDefaults.standard[.lastSelectedTemplateUUID] ?? "") }
        set { UserDefaults.standard[.lastSelectedTemplateUUID] = newValue?.uuidString }
    }

    func lock() {
        assert(Thread.isMainThread)
        lockedCount += 1
    }

    func unlock() {
        assert(Thread.isMainThread)
        lockedCount -= 1
    }

    func clearTeamplates() throws {
        assert(Thread.isMainThread)
        guard lockedCount == 0 else {
            throw Error.resourceBusy
        }

        self.templates
            .removeAll()
        self.enabledTemplates
            .removeAll()
        self.previewableTemplates
            .removeAll()
        self.templateMappings = nil

        self.selectedTemplate = nil
        NotificationCenter.default.post(
            name: NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
    }

    func reloadTemplates() throws {
        assert(Thread.isMainThread)
        guard lockedCount == 0 else {
            throw Error.resourceBusy
        }
        lockedCount += 1

        var errors: [(URL, Template.Error)] = []
        let enumerator = FileManager.default.enumerator(
            at: TemplateManager.templateRootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )!
        
        NotificationCenter.default.post(
            name: NotificationType.Name.templatesWillLoadNotification,
            object: self
        )

        // purpose: filter the greatest version of each template
        var newTemplates = Dictionary(
            grouping: enumerator
                .compactMap({ $0 as? URL })
                .filter({ $0.isRegularFile && $0.pathExtension == "lua" })
                .compactMap({ (url) -> Template? in
                    do {
                        return try Template(templateURL: url, templateManager: self)
                    } catch let error as Template.Error {
                        errors.append((url, error))
                    }
                    catch {}
                    return nil
                })
                .sorted(by: { $0.version.isVersion(greaterThan: $1.version) }),
            by: { $0.uuid }
        )
        .compactMap({ $0.1.first })

        newTemplates = newTemplates
            .sorted(by: { $0.name.compare($1.name) == .orderedAscending })

        self.templates
            .removeAll()
        self.enabledTemplates
            .removeAll()
        self.previewableTemplates
            .removeAll()

        self.templates
            .append(contentsOf: newTemplates)
        self.enabledTemplates
            .append(contentsOf: newTemplates.filter({ $0.isEnabled }))
        self.previewableTemplates
            .append(contentsOf: newTemplates.filter({ $0.isEnabled && $0.isPreviewable }))
        self.templateMappings = Dictionary(uniqueKeysWithValues: newTemplates.map({ ($0.uuid.uuidString, $0) }))

        errors.forEach({
            redirectTemplateError($0.1, templateURL: $0.0)
        })

        if !(self.selectedTemplate != nil) {
            self.selectedTemplate = newTemplates.first
        }

        lockedCount -= 1
        NotificationCenter.default.post(
            name: NotificationType.Name.templatesDidLoadNotification,
            object: self
        )
    }

    func redirectTemplateError(_ error: LocalizedError, templateURL url: URL) {
        os_log(
            "Cannot load template: %{public}@, failure reason: %{public}@",
            log: OSLog.default,
            type: .error,
            url.path,
            error.failureReason ?? ""
        )
    }
}
