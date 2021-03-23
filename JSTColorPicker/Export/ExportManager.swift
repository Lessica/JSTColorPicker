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
    
    enum Error: LocalizedError {
        case noDocumentLoaded
        case noTemplateSelected
        
        var failureReason: String? {
            switch self {
            case .noDocumentLoaded:
                return NSLocalizedString("No document loaded.", comment: "ExportError")
            case .noTemplateSelected:
                return NSLocalizedString("No template selected.", comment: "ExportError")
            }
        }
    }
    
    public static var templateRootURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent("templates")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    public static var exampleTemplateURLs: [URL] = {
        return [
            Bundle.main.url(forResource: "example", withExtension: "lua")!,
            Bundle.main.url(forResource: "pascal", withExtension: "lua")!
        ]
    }()
    public static private(set) var templates: [Template] = []
    public static var selectedTemplate: Template? {
        ExportManager.templates.first(where: { $0.uuid.uuidString == selectedTemplateUUID?.uuidString })
    }
    public static var selectedTemplateUUID: UUID? {
        get { UUID(uuidString: UserDefaults.standard[.lastSelectedTemplateUUID] ?? "") }
        set { UserDefaults.standard[.lastSelectedTemplateUUID] = newValue?.uuidString }
    }
    public static let templateIdentifierPrefix = "template-"
    
    @objc dynamic internal weak var screenshot: Screenshot!
    
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
    
    public var canImportFromAdditionalPasteboard: Bool {
        return (additionalPasteboard.canReadObject(
            forClasses: [PixelColor.self, PixelArea.self],
            options: nil
        ))
    }
    
    public func importFromAdditionalPasteboard() -> [ContentItem]? {
        return (additionalPasteboard.readObjects(
            forClasses: [PixelColor.self, PixelArea.self],
            options: nil
        )) as? [ContentItem]
    }
    
    public static func reloadTemplates() throws {
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
            if let uuid = ExportManager.templates.first?.uuid {
                selectedTemplateUUID = uuid
            }
        }
    }
    
    public func copyPixelColor(at coordinate: PixelCoordinate) throws {
        if let color = screenshot.image?.color(at: coordinate) {
            try copyContentItem(color)
        }
    }
    
    public func copyPixelArea(at rect: PixelRect) throws {
        if let area = screenshot.image?.area(at: rect) {
            try copyContentItem(area)
        }
    }
    
    public func copyContentItem(_ item: ContentItem) throws {
        try copyContentItems([item])
    }
    
    public func copyContentItems(_ items: [ContentItem]) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        guard let selectedTemplate = ExportManager.selectedTemplate else { throw Error.noTemplateSelected }
        do {
            exportToAdditionalPasteboard(items)
            exportToGeneralStringPasteboard(try selectedTemplate.generate(image, for: items))
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    public func copyAllContentItems() throws {
        guard let items = screenshot.content?.items else
        {
            throw Error.noDocumentLoaded
        }
        try copyContentItems(items)
    }
    
    public func exportContentItems(_ items: [ContentItem], to url: URL) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        guard let selectedTemplate = ExportManager.selectedTemplate else { throw Error.noTemplateSelected }
        do {
            if let data = (try selectedTemplate.generate(image, for: items)).data(using: .utf8) {
                try data.write(to: url)
            }
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    public func exportAllContentItems(to url: URL) throws {
        guard let items = screenshot.content?.items else
        {
            throw Error.noDocumentLoaded
        }
        try exportContentItems(items, to: url)
    }
    
    private func hardcodedCopyContentItemsLua(_ items: [ContentItem]) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        guard let exampleTemplateURL = ExportManager.exampleTemplateURLs.first else { throw Error.noTemplateSelected }
        let exampleTemplate = try Template(from: exampleTemplateURL)
        let generatedString = try exampleTemplate.generate(image, for: items)
        exportToGeneralStringPasteboard(generatedString)
    }
    
}
