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
        case incompatibleReturnedValue(action: Template.GenerateAction)
        
        var failureReason: String? {
            switch self {
            case .noDocumentLoaded:
                return NSLocalizedString("No document loaded.", comment: "ExportManager.Error")
            case .noTemplateSelected:
                return NSLocalizedString("No template selected.", comment: "ExportManager.Error")
            case .noExtensionSpecified:
                return NSLocalizedString("No output file extension specified.", comment: "ExportManager.Error")
            case .incompatibleReturnedValue(let action):
                return String(format: NSLocalizedString("Returned value is incompatible with action “%@”.", comment: "ExportManager.Error"), action.rawValue)
            }
        }
    }
    
    @objc dynamic weak var screenshot: Screenshot!
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
    }
    
    
    // MARK: - Pasteboard
    
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
}


// MARK: - Generate
extension ExportManager {
    
    @discardableResult
    func generateContentItems(
        _ items: [ContentItem],
        with template: Template,
        forAction action: Template.GenerateAction
    ) throws -> Template.GenerateResult
    {
        guard let image = screenshot.image else {
            throw Error.noDocumentLoaded
        }
        if action.isInteractive {
            try screenshot.testExportCondition()
        }
        guard Template.currentPlatformVersion
            .isVersion(greaterThanOrEqualTo: template.platformVersion)
        else {
            throw Template.Error
                .unsatisfiedPlatformVersion(version: template.platformVersion)
        }
        return try template.generate(image, items, forAction: action)
    }

    // convenience
    @discardableResult
    func generateAllContentItems(
        with template: Template,
        forAction action: Template.GenerateAction
    ) throws -> Template.GenerateResult
    {
        guard let items = screenshot.content?.items else {
            throw Error.noDocumentLoaded
        }
        return try generateContentItems(items, with: template, forAction: action)
    }
}


// MARK: - Preview
extension ExportManager {
    
    private func _previewContentItems(_ items: [ContentItem], with template: Template) throws -> String {
        do {
            switch try generateContentItems(items, with: template, forAction: .preview) {
            case .plain(let text):
                return text
            default:
                throw Error.incompatibleReturnedValue(action: .preview)
            }
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, template.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    // convenience preview
    func previewAllContentItems(with template: Template) throws -> String {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        return try _previewContentItems(items, with: template)
    }
}


// MARK: - Copy
extension ExportManager {
    
    private func _copyContentItems(_ items: [ContentItem], with template: Template) throws {
        do {
            exportToAdditionalPasteboard(items)
            switch try generateContentItems(items, with: template, forAction: .copy) {
            case .plain(let text):
                ExportManager.exportToGeneralStringPasteboard(text)
            default:
                throw Error.incompatibleReturnedValue(action: .copy)
            }
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, template.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    // convenience copy
    func copyPixelColor(at coordinate: PixelCoordinate, with template: Template) throws {
        if let color = screenshot.image?.color(at: coordinate) {
            try _copyContentItems([color], with: template)
        }
    }
    
    // convenience copy
    func copyPixelArea(at rect: PixelRect, with template: Template) throws {
        if let area = screenshot.image?.area(at: rect) {
            try _copyContentItems([area], with: template)
        }
    }
    
    // convenience copy
    func copyContentItem(_ item: ContentItem, with template: Template) throws {
        try _copyContentItems([item], with: template)
    }
    
    // convenience copy
    func copyContentItems(_ items: [ContentItem], with template: Template) throws {
        try _copyContentItems(items, with: template)
    }
    
    // convenience copy
    func copyAllContentItems(with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try _copyContentItems(items, with: template)
    }
}


// MARK: - Export
extension ExportManager {
    
    private func _exportContentItems(_ items: [ContentItem], to url: URL?, with template: Template) throws {
        do {
            if let url = url {
                // export
                switch try generateContentItems(items, with: template, forAction: .export) {
                case .plain(let text):
                    if let data = text.data(using: .utf8) {
                        try data.write(to: url)
                    }
                default:
                    throw Error.incompatibleReturnedValue(action: .export)
                }
            } else {
                // export in-place
                try generateContentItems(items, with: template, forAction: .exportInPlace)
            }
        } catch let error as Template.Error {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, template.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    // convenience export
    func exportContentItems(_ items: [ContentItem], to url: URL, with template: Template) throws {
        try _exportContentItems(items, to: url, with: template)
    }

    // convenience export in-place
    func exportContentItemsInPlace(_ items: [ContentItem], with template: Template) throws {
        try _exportContentItems(items, to: nil, with: template)
    }
    
    // convenience export
    func exportAllContentItems(to url: URL, with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try _exportContentItems(items, to: url, with: template)
    }

    // convenience export in-place
    func exportAllContentItemsInPlace(with template: Template) throws {
        guard let items = screenshot.content?.items else { throw Error.noDocumentLoaded }
        try _exportContentItems(items, to: nil, with: template)
    }
}


// MARK: - Hardcoded
extension ExportManager {
    
    // convenience copy
    private func hardcodedCopyContentItemsLua(_ items: [ContentItem]) throws {
        guard let image = screenshot.image else { throw Error.noDocumentLoaded }
        guard let exampleTemplateURL = TemplateManager.exampleTemplateURLs.first else { throw Error.noTemplateSelected }
        let exampleTemplate = try Template(templateURL: exampleTemplateURL, templateManager: TemplateManager.shared)
        let generatedResult = try exampleTemplate.generate(image, items, forAction: .copy)
        switch generatedResult {
        case .plain(let text):
            ExportManager.exportToGeneralStringPasteboard(text)
        default:
            break
        }
    }
}

