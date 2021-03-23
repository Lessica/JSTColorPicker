//
//  Defaults.swift
//  JSTColorPicker
//
//  Created by Darwin on 2/15/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

public extension UserDefaults.Key {
    
    static let AppleMomentumScrollSupported         : UserDefaults.Key     = "AppleMomentumScrollSupported"                    // Bool
    
    static let lastSelectedDeviceUDID               : UserDefaults.Key     = "defaults.lastSelectedDeviceUDID"                 // String
    static let lastSelectedTemplateUUID             : UserDefaults.Key     = "defaults.lastSelectedTemplateUUID"               // String
    static let enableNetworkDiscovery               : UserDefaults.Key     = "defaults.enableNetworkDiscovery"                 // Bool
    
    static let toggleTableColumnIdentifier          : UserDefaults.Key     = "defaults.tableColumn.toggle-id"                  // Bool
    static let toggleTableColumnSimilarity          : UserDefaults.Key     = "defaults.tableColumn.toggle-similarity"          // Bool
    static let toggleTableColumnTag                 : UserDefaults.Key     = "defaults.tableColumn.toggle-tag"                 // Bool
    static let toggleTableColumnDescription         : UserDefaults.Key     = "defaults.tableColumn.toggle-desc"                // Bool
    
    static let togglePaneViewInformation            : UserDefaults.Key     = "defaults.paneView.toggle-info"                   // Bool
    static let togglePaneViewInspector              : UserDefaults.Key     = "defaults.paneView.toggle-inspector"              // Bool
    static let togglePaneViewPreview                : UserDefaults.Key     = "defaults.paneView.toggle-preview"                // Bool
    static let togglePaneViewTagList                : UserDefaults.Key     = "defaults.paneView.toggle-taglist"                // Bool
    static let resetPaneView                        : UserDefaults.Key     = "defaults.paneView.reset"                         // Bool
    
    static let togglePreviewArea                    : UserDefaults.Key     = "defaults.preview.toggle-area"                    // Bool
    static let togglePreviewColor                   : UserDefaults.Key     = "defaults.preview.toggle-color"                   // Bool
    
    static let usesAlternativeAreaRepresentation    : UserDefaults.Key     = "defaults.usesAlternativeAreaRepresentation"      // Bool
    
    static let enableForceTouch                     : UserDefaults.Key     = "defaults.enableForceTouch"                       // Bool
    static let drawSceneBackground                  : UserDefaults.Key     = "defaults.drawSceneBackground"                    // Bool
    static let drawTagsInScene                      : UserDefaults.Key     = "defaults.drawTagsInScene"                        // Bool
    static let drawBordersInScene                   : UserDefaults.Key     = "defaults.drawBordersInScene"                     // Bool
    static let drawGridsInScene                     : UserDefaults.Key     = "defaults.drawGridsInScene"                       // Bool
    static let drawRulersInScene                    : UserDefaults.Key     = "defaults.drawRulersInScene"                      // Bool
    static let drawBackgroundInGridView             : UserDefaults.Key     = "defaults.drawBackgroundInGridView"               // Bool
    static let drawAnnotatorsInGridView             : UserDefaults.Key     = "defaults.drawAnnotatorsInGridView"               // Bool
    static let hideBordersWhenResize                : UserDefaults.Key     = "defaults.hideBordersWhenResize"                  // Bool
    static let hideGridsWhenResize                  : UserDefaults.Key     = "defaults.hideGridsWhenResize"                    // Bool
    static let hideAnnotatorsWhenResize             : UserDefaults.Key     = "defaults.hideAnnotatorsWhenResize"               // Bool
    static let usesPredominantAxisScrolling         : UserDefaults.Key     = "defaults.usesPredominantAxisScrolling"           // Bool
    
    static let usesDetailedToolTips                 : UserDefaults.Key     = "defaults.usesDetailedToolTips"                   // Bool
    static let confirmBeforeDelete                  : UserDefaults.Key     = "defaults.confirmBeforeDelete"                    // Bool
    static let ignoreInvalidDeletion                : UserDefaults.Key     = "defaults.ignoreInvalidDeletion"                  // Bool
    static let zIndexBySize                         : UserDefaults.Key     = "defaults.zIndexBySize"                           // Bool
    static let maximumItemCountEnabled              : UserDefaults.Key     = "defaults.maximumItemCountEnabled"                // Bool
    static let maximumItemCount                     : UserDefaults.Key     = "defaults.maximumItemCount"                       // Int
    
    static let screenshotSavingPath                 : UserDefaults.Key     = "defaults.screenshotSavingPath"                   // String
    
    static let pixelMatchThreshold                  : UserDefaults.Key     = "defaults.pixelMatchThreshold"                    // Double
    static let pixelMatchIncludeAA                  : UserDefaults.Key     = "defaults.pixelMatchIncludeAA"                    // Bool
    static let pixelMatchAlpha                      : UserDefaults.Key     = "defaults.pixelMatchAlpha"                        // Double
    static let pixelMatchAAColor                    : UserDefaults.Key     = "defaults.pixelMatchAAColor"                      // NSColor
    static let pixelMatchDiffColor                  : UserDefaults.Key     = "defaults.pixelMatchDiffColor"                    // NSColor
    static let pixelMatchDiffMask                   : UserDefaults.Key     = "defaults.pixelMatchDiffMask"                     // Bool
    static let pixelMatchBackgroundMode             : UserDefaults.Key     = "defaults.pixelMatchBackgroundMode"               // Bool
    
    static let enableGPUAcceleration                : UserDefaults.Key     = "defaults.enableGPUAcceleration"                  // Bool
    static let checkUpdatesAutomatically            : UserDefaults.Key     = "SUEnableAutomaticChecks"                         // Bool
    
    static let initialSimilarity                    : UserDefaults.Key     = "defaults.initialSimilarity"                      // Double
    
}

#if os(iOS)
import UIKit
public typealias SystemColor = UIColor
#else
import Cocoa
public typealias SystemColor = NSColor
#endif

public extension UserDefaults {

    func set<T>(_ value: T?, forKey key: Key) {
        set(value, forKey: key.rawValue)
    }

    func value<T>(forKey key: Key) -> T? {
        return value(forKey: key.rawValue) as? T
    }
    
    func removeObject(forKey key: Key) {
        removeObject(forKey: key.rawValue)
    }

    func register(defaults: [Key: Any?]) {
        let mapped = Dictionary(uniqueKeysWithValues: defaults.map { (key, value) -> (String, Any?) in
            if let color = value as? SystemColor {
                return (key.rawValue, NSKeyedArchiver.archivedData(withRootObject: color))
            } else if let url = value as? URL {
                return (key.rawValue, url.absoluteString)
            } else {
                return (key.rawValue, value)
            }
        }).compactMapValues({ $0 })
        
        register(defaults: mapped)
        NSUserDefaultsController.shared.initialValues = mapped
    }

}

public extension UserDefaults {

    subscript<T>(key: Key) -> T? {
        get { value(forKey: key)         }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> SystemColor? {
        get { color(forKey: key)         }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> URL? {
        get { url(forKey: key)           }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> Bool {
        get { bool(forKey: key)          }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> Int {
        get { integer(forKey: key)       }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> Double {
        get { double(forKey: key)        }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> Float {
        get { float(forKey: key)         }
        set { set(newValue, forKey: key) }
    }

    subscript(key: Key) -> CGFloat {
        get { CGFloat(float(forKey: key) as Float) }
        set { set(newValue, forKey: key)           }
    }

}

public extension UserDefaults {

    func bool(forKey key: Key) -> Bool {
        return bool(forKey: key.rawValue)
    }

    func integer(forKey key: Key) -> Int {
        return integer(forKey: key.rawValue)
    }

    func float(forKey key: Key) -> Float {
        return float(forKey: key.rawValue)
    }

    func float(forKey key: Key) -> CGFloat {
        return CGFloat(float(forKey: key) as Float)
    }

    func double(forKey key: Key) -> Double {
        return double(forKey: key.rawValue)
    }

    func url(forKey key: Key) -> URL? {
        return string(forKey: key).flatMap { URL(string: $0) }
    }

    func date(forKey key: Key) -> Date? {
        return object(forKey: key.rawValue) as? Date
    }

    func string(forKey key: Key) -> String? {
        return string(forKey: key.rawValue)
    }

    func set(_ url: URL?, forKey key: Key) {
        set(url?.absoluteString, forKey: key.rawValue)
    }

    func set(_ color: SystemColor?, forKey key: Key) {
        guard let color = color else {
            set(nil, forKey: key.rawValue)
            return
        }

        let data = NSKeyedArchiver.archivedData(withRootObject: color)
        set(data, forKey: key.rawValue)
    }

    func color(forKey key: Key) -> SystemColor? {
        return data(forKey: key.rawValue)
            .flatMap { NSKeyedUnarchiver.unarchiveObject(with: $0) as? SystemColor }
    }

}

public extension UserDefaults {

    struct Key: Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral {

        public var rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

    }

}