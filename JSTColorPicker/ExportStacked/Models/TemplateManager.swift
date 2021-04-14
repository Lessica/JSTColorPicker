//
//  TemplateManager.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/13/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import OSLog

class TemplateManager {

    static var shared = TemplateManager()

    struct NotificationType {
        struct Name {
            static let templatesDidLoadNotification = NSNotification.Name(rawValue: "TemplateManager.templatesDidLoadNotification")
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
            Bundle.main.url(forResource: "example", withExtension: "lua")!,
            Bundle.main.url(forResource: "pascal", withExtension: "lua")!
        ]
    }()

    private(set) var templates: [Template] = []

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

    func clearTeamplates() {
        templates
            .removeAll()

        selectedTemplate = nil
        NotificationCenter.default.post(
            name: NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
    }

    func reloadTemplates() throws {
        var errors: [(URL, Template.Error)] = []
        let contents = try FileManager.default.contentsOfDirectory(
            at: TemplateManager.templateRootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        // purpose: filter the greatest version of each template
        let newTemplates = Dictionary(
            grouping: contents
                .filter({ $0.pathExtension == "lua" })
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

        self.templates
            .removeAll()
        self.templates
            .append(contentsOf: newTemplates)

        errors.forEach({
            redirectTemplateError($0.1, templateURL: $0.0)
        })

        if !(self.selectedTemplate != nil) {
            self.selectedTemplate = newTemplates.first
        }

        NotificationCenter.default.post(
            name: NotificationType.Name.templatesDidLoadNotification,
            object: nil
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
