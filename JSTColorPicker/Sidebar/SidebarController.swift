//
//  SidebarController.swift
//  JSTColorPicker
//
//  Created by Darwin on 1/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let newLength = self.count
        if newLength < toLength {
            return String(repeatElement(character, count: toLength - newLength)) + self
        } else {
            let idx = self.index(self.startIndex, offsetBy: newLength - toLength)
            return String(self[..<idx])
        }
    }
}

extension NSImage {
    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }
}

class SidebarController: NSViewController {

    @IBOutlet weak var imageLabel: NSTextField!
    @IBOutlet weak var inspectorColorLabel: NSTextField!
    @IBOutlet weak var inspectorColorFlag: NSImageView!
    @IBOutlet weak var inspectorPositionLabel: NSTextField!
    
    fileprivate static var byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter.init()
        return formatter
    }()
    fileprivate static var exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    fileprivate static var defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter.init()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetController()
    }
    
    func renderImageSource(_ source: CGImageSource, itemURL: URL) throws {
        guard let fileProps = CGImageSourceCopyProperties(source, nil) as? [AnyHashable: Any] else {
            return
        }
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] else {
            return
        }
        let createdAtStr = (props[kCGImagePropertyExifDictionary] as? [AnyHashable: Any] ?? [:])[kCGImagePropertyExifDateTimeOriginal] as? String ?? "Unknown"
        var createdAt: String?
        if let date = SidebarController.exifDateFormatter.date(from: createdAtStr) {
            createdAt = SidebarController.defaultDateFormatter.string(from: date)
        }
        let fileSize = SidebarController.byteFormatter.string(fromByteCount: fileProps[kCGImagePropertyFileSize] as? Int64 ?? 0)
        let pixelXDimension = props[kCGImagePropertyPixelWidth] as? Int64 ?? 0
        let pixelYDimension = props[kCGImagePropertyPixelHeight] as? Int64 ?? 0
        imageLabel.stringValue = """
\(itemURL.lastPathComponent) (\(fileSize))

Created: \(createdAt ?? "Unknown")
Dimensions: \(pixelXDimension)×\(pixelYDimension)
Orientation: \(props[kCGImagePropertyOrientation] ?? "Unknown")
Color Space: \(props[kCGImagePropertyColorModel] ?? "Unknown")
Color Profile: \(props[kCGImagePropertyProfileName] ?? "Unknown")
"""
    }
    
    func updateInspector(point: CGPoint, color: JSTPixelColor) {
//        debugPrint("(\(point.x), \(point.y), \(color.getHex()))")
        inspectorColorLabel.stringValue = """
R:\(String(color.red).leftPadding(toLength: 5, withPad: " "))  =\(String(format: "0x%02X", color.red))
G:\(String(color.green).leftPadding(toLength: 5, withPad: " "))  =\(String(format: "0x%02X", color.green))
B:\(String(color.blue).leftPadding(toLength: 5, withPad: " "))  =\(String(format: "0x%02X", color.blue))
A:\(String(Int(Double(color.alpha) / 255.0 * 100)).leftPadding(toLength: 5, withPad: " "))% =\(String(format: "0x%02X", color.alpha))
"""
        inspectorColorFlag.image = NSImage.init(color: color.getNSColor(), size: inspectorColorFlag.bounds.size)
        inspectorPositionLabel.stringValue = """
X:\(String(Int(point.x)).leftPadding(toLength: 5, withPad: " "))
Y:\(String(Int(point.y)).leftPadding(toLength: 5, withPad: " "))
"""
    }
    
    func resetController() {
        imageLabel.stringValue = "Open or drop an image here."
        inspectorColorFlag.image = NSImage()
        inspectorColorLabel.stringValue = """
R:
G:
B:
A:
"""
        inspectorPositionLabel.stringValue = """
X:
Y:
"""
    }
    
    deinit {
        debugPrint("- [SidebarController deinit]")
    }
    
}
