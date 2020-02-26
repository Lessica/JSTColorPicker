//
//  ExportManager.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

import OSLog
import Foundation

extension String {
    
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()

        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }

        return results.map { String($0) }
    }
    
}

extension Array {
    
    func filterDuplicates(includeElement: (_ lhs:Element, _ rhs:Element) -> Bool) -> [Element] {
        var results = [Element]()
        forEach { (element) in
            let existingElements = results.filter {
                return includeElement(element, $0)
            }
            if existingElements.count == 0 {
                results.append(element)
            }
        }
        return results
    }
    
}

enum ExportError: LocalizedError {
    case noDocumentLoaded
    case noTemplateSelected
    
    var failureReason: String? {
        switch self {
        case .noDocumentLoaded:
            return "No document loaded."
        case .noTemplateSelected:
            return "No template selected."
        }
    }
}

class ExportManager {
    
    static var templateRootURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(Bundle.main.bundleIdentifier!).appendingPathComponent("templates")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
        return url
    }
    
    static var exampleTemplateURL: URL? {
        return Bundle.main.url(forResource: "example", withExtension: "lua")
    }
    
    var templates: [Template] = []
    var selectedTemplate: Template? {
        templates.first(where: { $0.uuid.uuidString == selectedTemplateUUID?.uuidString })
    }
    var selectedTemplateUUID: UUID? {
        get {
            return UUID(uuidString: UserDefaults.standard[.lastSelectedTemplateUUID] ?? "")
        }
        set {
            UserDefaults.standard[.lastSelectedTemplateUUID] = newValue?.uuidString
        }
    }
    
    weak var screenshot: Screenshot?
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
        try? reloadTemplates()
    }
    
    fileprivate func exportToPasteboardAsString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    func reloadTemplates() throws {
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
        errors.forEach({ os_log("Cannot load template: %@, failure reason: %@", log: OSLog.default, type: .error, $0.0.path, $0.1.failureReason ?? "") })
        
        if !(selectedTemplate != nil) {
            if let uuid = self.templates.first?.uuid {
                selectedTemplateUUID = uuid
            }
        }
    }
    
    func copyPixelColor(at coordinate: PixelCoordinate) throws {
        if let color = screenshot?.image?.color(at: coordinate) {
            try copyContentItem(color)
        }
    }
    
    func copyPixelArea(at rect: PixelRect) throws {
        if let area = screenshot?.image?.area(at: rect) {
            try copyContentItem(area)
        }
    }
    
    func copyContentItem(_ item: ContentItem) throws {
        try copyContentItems([item])
    }
    
    func copyContentItems(_ items: [ContentItem]) throws {
        guard let image = screenshot?.image else { throw ExportError.noDocumentLoaded }
        guard let selectedTemplate = selectedTemplate else { throw ExportError.noTemplateSelected }
        do {
            exportToPasteboardAsString(try selectedTemplate.generate(image, for: items))
        } catch let error as TemplateError {
            os_log("Cannot generate template: %@, failure reason: %@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch let error {
            throw error
        }
    }
    
    func exportAllItems(to url: URL) throws {
        guard let screenshot = screenshot,
            let image = screenshot.image,
            let items = screenshot.content?.items else
        {
            throw ExportError.noDocumentLoaded
        }
        guard let selectedTemplate = selectedTemplate else { throw ExportError.noTemplateSelected }
        do {
            if let data = (try selectedTemplate.generate(image, for: items)).data(using: .utf8) {
                try data.write(to: url)
            }
        } catch let error as TemplateError {
            os_log("Cannot generate template: %@, failure reason: %@", log: OSLog.default, type: .error, selectedTemplate.url.path, error.failureReason ?? "")
            throw error
        } catch let error {
            throw error
        }
    }
    
    private func hardcodedCopyContentItemsLua(_ items: [ContentItem]) throws {
        guard let image = screenshot?.image else { throw ExportError.noDocumentLoaded }
        guard let exampleTemplateURL = ExportManager.exampleTemplateURL else { throw ExportError.noTemplateSelected }
        let exampleTemplate = try Template(from: exampleTemplateURL)
        let generatedString = try exampleTemplate.generate(image, for: items)
        exportToPasteboardAsString(generatedString)
    }
    
    private func hardcodedCopyContentItemsNative(_ items: [ContentItem]) throws {
        if items.count == 1 {
            if let item = items.first {
                if let color = item as? PixelColor {
                    exportToPasteboardAsString("\(String(color.coordinate.x).leftPadding(to: 4, with: " ")), \(String(color.coordinate.y).leftPadding(to: 4, with: " ")), \(color.pixelColorRep.hexString.leftPadding(to: 8, with: " ")), \(String(format: "%.2f", color.similarity * 100.0).leftPadding(to: 6, with: " "))")
                }
                else if let area = item as? PixelArea {
                    if let data = screenshot?.image?.pngRepresentation(of: area) {
                        let dataString = data.map {
                            String(format: "\\x%02hhx", $0)
                        }
                        .joined().split(by: 64).joined(separator: "\n")
                        exportToPasteboardAsString("""
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
            
            outputString += "{\n"
            items.compactMap({ $0 as? PixelColor })
                .forEach({ outputString += "  { \(String($0.coordinate.x).leftPadding(to: 4, with: " ")), \(String($0.coordinate.y).leftPadding(to: 4, with: " ")), \($0.pixelColorRep.hexString.leftPadding(to: 8, with: " ")), \(String(format: "%.2f", $0.similarity * 100.0).leftPadding(to: 6, with: " ")) },  -- \($0.id)\n" })
            outputString += "}"
            
            if let area = items.compactMap({ $0 as? PixelArea }).first {
                outputString += ", \(String(format: "%.2f", area.similarity * 100.0)), \(String(area.rect.origin.x)), \(String(area.rect.origin.y)), \(String(area.rect.opposite.x)), \(String(area.rect.opposite.y)))"
            } else {
                outputString += ")"
            }
            
            exportToPasteboardAsString(outputString)
        }
    }
    
}
