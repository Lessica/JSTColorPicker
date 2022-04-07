//
//  ExportManager.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation
import OSLog

extension NSPasteboard.Name {
    static let jstColorPicker = NSPasteboard.Name("com.jst.JSTColorPicker.pasteboard")
}

final class ExportManager {
    
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
    
    @objc dynamic weak var screenshot: Screenshot!
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
    }
    
    internal static func exportToGeneralStringPasteboard(_ string: String) {
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
        try _copyContentItems(items, with: template)
    }
    
    private func _copyContentItems(_ items: [ContentItem], with template: Template) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        try screenshot.testExportCondition()
        do {
            exportToAdditionalPasteboard(items)
            ExportManager.exportToGeneralStringPasteboard(try template.generate(image, items, forAction: .copy))
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

    func generateContentItems(_ items: [ContentItem], with template: Template, forAction action: Template.GenerateAction) throws -> String {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        if action != .preview {
            try screenshot.testExportCondition()
        }
        return try template.generate(image, items, forAction: action)
    }

    func generateAllContentItems(with template: Template, forAction action: Template.GenerateAction) throws -> String {
        guard let image = screenshot.image,
              let items = screenshot.content?.items
        else { throw Error.noDocumentLoaded }
        if action != .preview {
            try screenshot.testExportCondition()
        }
        return try template.generate(image, items, forAction: action)
    }

    private func _exportContentItems(_ items: [ContentItem], to url: URL?, with template: Template) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        try screenshot.testExportCondition()
        do {
            if let url = url {
                if let data = (try template.generate(image, items, forAction: .export)).data(using: .utf8) {
                    try data.write(to: url)
                }
            } else {
                _ = try template.generate(image, items, forAction: .export)
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
        guard let exampleTemplateURL = TemplateManager.exampleTemplateURLs.first else { throw Error.noTemplateSelected }
        let exampleTemplate = try Template(templateURL: exampleTemplateURL, templateManager: TemplateManager.shared)
        let generatedString = try exampleTemplate.generate(image, items, forAction: .copy)
        ExportManager.exportToGeneralStringPasteboard(generatedString)
    }
    
}
