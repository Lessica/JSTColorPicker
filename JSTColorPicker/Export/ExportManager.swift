//
//  ExportManager.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

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

class ExportManager {
    
    weak var screenshot: Screenshot?
    
    required init(screenshot: Screenshot) {
        self.screenshot = screenshot
    }
    
    fileprivate func exportToPasteboardAsString(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(string, forType: .string)
    }
    
    func copyPixelColor(at coordinate: PixelCoordinate) {
        if let color = screenshot?.image?.color(at: coordinate) {
            copyContentItem(color)
        }
    }
    
    func copyPixelArea(at rect: PixelRect) {
        if let area = screenshot?.image?.area(at: rect) {
            copyContentItem(area)
        }
    }
    
    func copyContentItem(_ item: ContentItem) {
        if let color = item as? PixelColor {
            exportToPasteboardAsString("\(String(color.coordinate.x).leftPadding(to: 4, with: " ")), \(String(color.coordinate.y).leftPadding(to: 4, with: " ")), \(color.pixelColorRep.hexString.leftPadding(to: 8, with: " ")), \(String(format: "%.2f", color.similarity * 100.0).leftPadding(to: 6, with: " "))")
        }
        else if let area = item as? PixelArea {
            if let data = screenshot?.image?.pixelImageRep.crop(area.rect.toCGRect()).pngRepresentation() {
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
    
    func copyContentItems(_ items: [ContentItem]) {
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
