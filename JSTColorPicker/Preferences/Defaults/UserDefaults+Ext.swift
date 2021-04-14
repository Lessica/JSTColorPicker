//
//  UserDefaults+Ext.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
typealias SystemColor = UIColor
#else
import Cocoa
typealias SystemColor = NSColor
#endif

extension UserDefaults {

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

extension UserDefaults {

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

extension UserDefaults {

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

extension UserDefaults {
    struct Key: Codable, Hashable, RawRepresentable, ExpressibleByStringLiteral {
        var rawValue: String
        init(rawValue: String) {
            self.rawValue = rawValue
        }
        init(stringLiteral value: String) {
            self.rawValue = value
        }
    }

    func observe<T: Any>(key: String, callback: @escaping (T) -> Void) -> Observable {
        let result = KeyValueObserver<T>.observeNew(object: self, keyPath: key) {
            callback($0)
        }
        return result
    }

    func observeString(key: String, callback: @escaping (String) -> Void) -> Observable {
        return observe(key: key, callback: callback)
    }
}
