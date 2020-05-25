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

enum ExportError: LocalizedError {
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

class ExportManager {
    
    public static var templateRootURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent("templates")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    public static var exampleTemplateURL: URL? {
        return Bundle.main.url(forResource: "example", withExtension: "lua")
    }
    public fileprivate(set) var templates: [Template] = []
    public var selectedTemplate: Template? {
        templates.first(where: { $0.uuid.uuidString == selectedTemplateUUID?.uuidString })
    }
    public var selectedTemplateUUID: UUID? {
        get { return UUID(uuidString: UserDefaults.standard[.lastSelectedTemplateUUID] ?? "") }
        set { UserDefaults.standard[.lastSelectedTemplateUUID] = newValue?.uuidString }
    }
    
    public weak var screenshot: Screenshot?
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
        try? reloadTemplates()
    }
    
    fileprivate func exportToGeneralStringPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    fileprivate lazy var additionalPasteboard = {
        return NSPasteboard(name: .jstColorPicker)
    }()
    
    fileprivate func exportToAdditionalPasteboard(_ items: [ContentItem]) {
        additionalPasteboard.clearContents()
        additionalPasteboard.writeObjects(items)
    }
    
    public var canImportFromAdditionalPasteboard: Bool {
        return additionalPasteboard.canReadObject(forClasses: [ContentItem.self], options: nil)
    }
    
    public func importFromAdditionalPasteboard() -> [ContentItem]? {
        let objects = additionalPasteboard.readObjects(forClasses: [ContentItem.self], options: nil)
        return objects as? [ContentItem]
    }
    
    public func reloadTemplates() throws {
        var errors: [(URL, TemplateError)] = []
        let contents = try FileManager.default.contentsOfDirectory(at: ExportManager.templateRootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        // purpose: filter the greatest version of each template
        let templates = Dictionary(grouping: contents
            .filter({ $0.pathExtension == "lua" })
            .compactMap({ (url) -> Template? in
                do {
                    return try Template(from: url)
                } catch let error as TemplateError {
                    errors.append((url, error))
                }
                catch {}
                return nil
            })
            .sorted(by: { $0.version.isVersion(greaterThan: $1.version) }), by: { $0.uuid })
            .compactMap({ $0.1.first })
        
        // templates.forEach({ dump($0) })
        self.templates.removeAll()
        self.templates.append(contentsOf: templates)
        errors.forEach({ os_log("Cannot load template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, $0.0.path, $0.1.failureReason ?? "") })
        
        if !(selectedTemplate != nil) {
            if let uuid = self.templates.first?.uuid {
                selectedTemplateUUID = uuid
            }
        }
    }
    
    public func copyPixelColor(at coordinate: PixelCoordinate) throws {
        if let color = screenshot?.image?.color(at: coordinate) {
            try copyContentItem(color)
        }
    }
    
    public func copyPixelArea(at rect: PixelRect) throws {
        if let area = screenshot?.image?.area(at: rect) {
            try copyContentItem(area)
        }
    }
    
    public func copyContentItem(_ item: ContentItem) throws {
        try copyContentItems([item])
    }
    
    public func copyContentItems(_ items: [ContentItem]) throws {
        guard let image = screenshot?.image else { throw ExportError.noDocumentLoaded }
        guard let selectedTemplate = selectedTemplate else { throw ExportError.noTemplateSelected }
        do {
            exportToAdditionalPasteboard(items)
            exportToGeneralStringPasteboard(try selectedTemplate.generate(image, for: items))
        } catch let error as TemplateError {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    public func exportItems(_ items: [ContentItem], to url: URL) throws {
        guard let image = screenshot?.image else { throw ExportError.noDocumentLoaded }
        guard let selectedTemplate = selectedTemplate else { throw ExportError.noTemplateSelected }
        do {
            if let data = (try selectedTemplate.generate(image, for: items)).data(using: .utf8) {
                try data.write(to: url)
            }
        } catch let error as TemplateError {
            os_log("Cannot generate template: %{public}@, failure reason: %{public}@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch {
            throw error
        }
    }
    
    public func exportAllItems(to url: URL) throws {
        guard let items = screenshot?.content?.items else
        {
            throw ExportError.noDocumentLoaded
        }
        try exportItems(items, to: url)
    }
    
    private func hardcodedCopyContentItemsLua(_ items: [ContentItem]) throws {
        guard let image = screenshot?.image else { throw ExportError.noDocumentLoaded }
        guard let exampleTemplateURL = ExportManager.exampleTemplateURL else { throw ExportError.noTemplateSelected }
        let exampleTemplate = try Template(from: exampleTemplateURL)
        let generatedString = try exampleTemplate.generate(image, for: items)
        exportToGeneralStringPasteboard(generatedString)
    }
    
    private func hardcodedCopyContentItemsNative(_ items: [ContentItem]) throws {
        if items.count == 1 {
            if let item = items.first {
                if let color = item as? PixelColor {
                    exportToGeneralStringPasteboard("\(String(color.coordinate.x).leftPadding(to: 4, with: " ")), \(String(color.coordinate.y).leftPadding(to: 4, with: " ")), \(color.pixelColorRep.hexString.leftPadding(to: 8, with: " ")), \(String(format: "%.2f", color.similarity * 100.0).leftPadding(to: 6, with: " "))")
                }
                else if let area = item as? PixelArea {
                    if let data = screenshot?.image?.pngRepresentation(of: area) {
                        let dataString = data.map {
                            String(format: "\\x%02hhx", $0)
                        }
                        .joined().split(by: 64).joined(separator: "\n")
                        exportToGeneralStringPasteboard("""
x, y = screen.find_image([[
\(dataString)
]], \(String(format: "%.2f", area.similarity * 100.0)), \(String(area.rect.origin.x)), \(String(area.rect.origin.y)), \(String(area.rect.opposite.x)), \(String(area.rect.opposite.y)))
""")
                    }
                }
            }
        }
        else {
            var outputString = "x, y = screen.find_color("
            
            outputString += items
                .compactMap({ $0 as? PixelColor })
                .reduce("{\n", { $0 + "  { \(String($1.coordinate.x).leftPadding(to: 4, with: " ")), \(String($1.coordinate.y).leftPadding(to: 4, with: " ")), \($1.pixelColorRep.hexString.leftPadding(to: 8, with: " ")), \(String(format: "%.2f", $1.similarity * 100.0).leftPadding(to: 6, with: " ")) },  -- \($1.id)\n" }) + "}"
            
            if let area = items.compactMap({ $0 as? PixelArea }).first {
                outputString += ", \(String(format: "%.2f", area.similarity * 100.0)), \(String(area.rect.origin.x)), \(String(area.rect.origin.y)), \(String(area.rect.opposite.x)), \(String(area.rect.opposite.y)))"
            } else {
                outputString += ")"
            }
            
            exportToGeneralStringPasteboard(outputString)
        }
    }
    
}
