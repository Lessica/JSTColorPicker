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
                return (key.rawValue, try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true))
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

        let data = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
        set(data, forKey: key.rawValue)
    }

    func color(forKey key: Key) -> SystemColor? {
        return data(forKey: key.rawValue)
            .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: SystemColor.self, from: $0) }
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

    func observe<T: Any>(
        key: UserDefaults.Key,
        callback: @escaping (_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: T) -> Void
    ) -> Observable
    {
        return KeyValueObserver<T>.observeNew(
            object: self,
            keyPath: key.rawValue
        ) {
            callback(self, key, $0)
        }
    }

    func observe<T: Any>(
        keys: [UserDefaults.Key],
        callback: @escaping (_ defaults: UserDefaults, _ defaultKey: UserDefaults.Key, _ defaultValue: T) -> Void
    ) -> [Observable]
    {
        return keys.compactMap(
            { key in
                KeyValueObserver<T>.observeNew(
                    object: self,
                    keyPath: key.rawValue
                ) { value in
                    callback(self, key, value)
                }
            }
        )
    }
}
