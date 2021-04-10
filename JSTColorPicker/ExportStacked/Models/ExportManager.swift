//
//  ExportManager.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import OSLog
import Foundation

extension NSPasteboard.Name {
    static let jstColorPicker = NSPasteboard.Name("com.jst.JSTColorPicker.pasteboard")
}

class ExportManager {
    
    struct NotificationType {
        struct Name {
            static let templatesDidLoadNotification = NSNotification.Name(rawValue: "ExportManagerTemplatesDidLoadNotification")
            static let selectedTemplateDidChangeNotification = NSNotification.Name(rawValue: "ExportManagerSelectedTemplateDidChangeNotification")
        }
        struct Key {
            static let template = "template"
            static let templateUUID = "uuid"
        }
    }
    
    enum Error: LocalizedError {
        case noDocumentLoaded
        case noTemplateSelected
        case noExtensionSpecified
        
        var failureReason: String? {
            switch self {
            case .noDocumentLoaded:
                return NSLocalizedString("No document loaded.", comment: "ExportError")
            case .noTemplateSelected:
                return NSLocalizedString("No template selected.", comment: "ExportError")
            case .noExtensionSpecified:
                return NSLocalizedString("No output file extension specified.", comment: "ExportError")
            }
        }
    }
    
    static var templateRootURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent("templates")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    
    static var exampleTemplateURLs: [URL] = {
        return [
            Bundle.main.url(forResource: "example", withExtension: "lua")!,
            Bundle.main.url(forResource: "pascal", withExtension: "lua")!
        ]
    }()
    
    private(set) static var templates: [Template] = []
    static var selectedTemplate: Template? {
        get { ExportManager.templates.first(where: { $0.uuid.uuidString == selectedTemplateUUID?.uuidString }) }
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
    private(set) static var selectedTemplateUUID: UUID? {
        get { UUID(uuidString: UserDefaults.standard[.lastSelectedTemplateUUID] ?? "") }
        set { UserDefaults.standard[.lastSelectedTemplateUUID] = newValue?.uuidString }
    }
    
    @objc dynamic weak var screenshot: Screenshot!
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
    }
    
    private func exportToGeneralStringPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    private lazy var additionalPasteboard = {
        return NSPasteboard(name: .jstColorPicker)
    }()
    
    private func exportToAdditionalPasteboard(_ items: [ContentItem]) {
        additionalPasteboard.clearContents()
        additionalPasteboard.writeObjects(items)
    }
    
    var canImportFromAdditionalPasteboard: Bool {
        return additionalPasteboard.canReadObject(
            forClasses: [PixelColor.self, PixelArea.self],
            options: nil
        )
    }
    
    func importFromAdditionalPasteboard() -> [ContentItem]? {
        return additionalPasteboard.readObjects(
            forClasses: [PixelColor.self, PixelArea.self],
            options: nil
        ) as? [ContentItem]
    }
    
    static func reloadTemplates() throws {
        var errors: [(URL, Template.Error)] = []
        let contents = try FileManager.default.contentsOfDirectory(at: ExportManager.templateRootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        // purpose: filter the greatest version of each template
        let templates = Dictionary(grouping: contents
            .filter({ $0.pathExtension == "lua" })
            .compactMap({ (url) -> Template? in
                do {
                    return try Template(from: url)
                } catch let error as Template.Error {
                    errors.append((url, error))
                }
                catch {}
                return nil
            })
            .sorted(by: { $0.version.isVersion(greaterThan: $1.version) }), by: { $0.uuid })
            .compactMap({ $0.1.first })
        
        // ExportManager.templates.forEach({ dump($0) })
        ExportManager.templates.removeAll()
        ExportManager.templates.append(contentsOf: templates)
        errors.forEach({ os_log("Cannot load template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, $0.0.path, $0.1.failureReason ?? "") })
        
        if !(selectedTemplate != nil) {
            selectedTemplate = ExportManager.templates.first
        }
        
        NotificationCenter.default.post(
            name: NotificationType.Name.templatesDidLoadNotification,
            object: nil
        )
    }
    
    func copyPixelColor(at coordinate: PixelCoordinate, with template: Template) throws {
        if let color = screenshot.image?.color(at: coordinate) {
            try copyContentItem(color, with: template)
        }
    }
    
    func copyPixelArea(at rect: PixelRect, with template: Template) throws {
        if let area = screenshot.image?.area(at: rect) {
            try copyContentItem(area, with: template)
        }
    }
    
    func copyContentItem(_ item: ContentItem, with template: Template) throws {
        try copyContentItems([item], with: template)
    }
    
    func copyContentItems(_ items: [ContentItem], with template: Template) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        do {
            exportToAdditionalPasteboard(items)
            exportToGeneralStringPasteboard(try template.generate(image, for: items))
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, template.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    func copyAllContentItems(with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try copyContentItems(items, with: template)
    }

    private func _exportContentItems(_ items: [ContentItem], to url: URL?, with template: Template) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        do {
            if let url = url {
                if let data = (try template.generate(image, for: items)).data(using: .utf8) {
                    try data.write(to: url)
                }
            } else {
                _ = try template.generate(image, for: items)
            }
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, template.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    func exportContentItems(_ items: [ContentItem], to url: URL, with template: Template) throws {
        try _exportContentItems(items, to: url, with: template)
    }

    func exportContentItemsInPlace(_ items: [ContentItem], with template: Template) throws {
        try _exportContentItems(items, to: nil, with: template)
    }
    
    func exportAllContentItems(to url: URL, with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try _exportContentItems(items, to: url, with: template)
    }

    func exportAllContentItemsInPlace(with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try _exportContentItems(items, to: nil, with: template)
    }
    
    private func hardcodedCopyContentItemsLua(_ items: [ContentItem]) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        guard let exampleTemplateURL = ExportManager.exampleTemplateURLs.first else { throw Error.noTemplateSelected }
        let exampleTemplate = try Template(from: exampleTemplateURL)
        let generatedString = try exampleTemplate.generate(image, for: items)
        exportToGeneralStringPasteboard(generatedString)
    }
    
}
