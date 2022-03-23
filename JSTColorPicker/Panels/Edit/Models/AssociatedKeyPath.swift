//
//  AssociatedKeyPath.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/3/23.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

@objc
final class AssociatedKeyPath: NSObject, NSCopying {
    internal init(name: String, type: AssociatedKeyPath.ValueType, value: Any? = nil, options: [String]? = nil, helpText: String? = nil) {
        self.name = name
        self.type = type
        self.value = value
        self.options = options
        self.helpText = helpText
        super.init()
        allowsKVONotification = true
    }

    static var initializedOrder = 0

    override init() {
        AssociatedKeyPath.initializedOrder += 1
        name = "keyPath #\(AssociatedKeyPath.initializedOrder)"
        type = .Boolean
        value = false
        options = nil
        helpText = nil
        super.init()
        allowsKVONotification = true
    }

    @objc
    enum ValueType: Int {
        case Boolean // checkbox
        case Integer // text input
        case Decimal // text input
        case String // text input
        case Point // not implemented
        case Size // not implemented
        case Rect // not implemented
        case Range // not implemented
        case Color // not implemented
        case Image // not implemented
        case Nil // nothing

        init(string: Field.StringValueType) {
            switch string {
            case .Boolean:
                self = .Boolean
            case .Integer:
                self = .Integer
            case .Decimal:
                self = .Decimal
            case .String:
                self = .String
            case .Point:
                self = .Point
            case .Size:
                self = .Size
            case .Rect:
                self = .Rect
            case .Range:
                self = .Range
            case .Color:
                self = .Color
            case .Image:
                self = .Image
            case .Nil:
                self = .Nil
            }
        }
    }

    @objc dynamic var name: String
    @objc dynamic var type: ValueType {
        didSet {
            updateDynamicVariables()
        }
    }

    @objc dynamic var value: Any?
    @objc dynamic var options: [String]? {
        didSet {
            updateDynamicVariables()
        }
    }

    @objc dynamic var helpText: String?

    @objc dynamic var hasOptions = false
    @objc dynamic var isCheckboxValue = true
    @objc dynamic var isTextInputValue = false
    @objc dynamic var isTextInputIntegerValue = false
    @objc dynamic var isTextInputDecimalValue = false

    func copy(with zone: NSZone? = nil) -> Any {
        return AssociatedKeyPath(
            name: name,
            type: type,
            value: value,
            options: options,
            helpText: helpText
        )
    }

    private func updateDynamicVariables() {
        hasOptions = options?.count ?? 0 > 0
        switch type {
        case .Boolean:
            isCheckboxValue = !hasOptions
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Integer:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = !hasOptions
            isTextInputDecimalValue = false
        case .Decimal:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = !hasOptions
        case .String:
            isCheckboxValue = false
            isTextInputValue = !hasOptions
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Point:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Size:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Rect:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Range:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Color:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Image:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        case .Nil:
            isCheckboxValue = false
            isTextInputValue = false
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
        }
    }

    var allowsKVONotification = false

    func resetDynamicVariables() {
        let allow = allowsKVONotification
        allowsKVONotification = false
        name = { self.name }()
        type = { self.type }()
        value = { self.value }()
        options = { self.options }()
        helpText = { self.helpText }()
        allowsKVONotification = allow
    }

    var stringValue: String? {
        if let value = value {
            return "\(value)"
        }
        return nil
    }

    var intValue: Int? {
        if let value = value as? Bool {
            return value ? 1 : 0
        } else if let value = value as? Int {
            return value
        } else if let value = value as? Double {
            return Int(value)
        } else if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    var doubleValue: Double? {
        if let value = value as? Bool {
            return value ? 1.0 : 0.0
        } else if let value = value as? Int {
            return Double(value)
        } else if let value = value as? Double {
            return value
        } else if let value = value as? String {
            return Double(value)
        }
        return nil
    }

    var boolValue: Bool? {
        if let value = value as? Bool {
            return value
        } else if let value = value as? Int {
            return value != 0
        } else if let value = value as? Double {
            return value > 0
        } else if let value = value as? String {
            let rawValue = value.lowercased()
            return !(rawValue.hasPrefix("f") || rawValue.hasPrefix("n") || rawValue.hasPrefix("0"))
        }
        return nil
    }
    
    var booleanValue: Bool? { boolValue }

    var keyValuePairs: (String, String) {
        let aKey = self.name
        var aValue: String?
        switch type {
        case .Boolean:
            aValue = (boolValue ?? false) ? "YES" : "NO"
        case .Integer:
            aValue = "\(intValue ?? 0)"
        case .Decimal:
            aValue = "\(doubleValue ?? 0.0)"
        case .String:
            aValue = stringValue ?? ""
        default:
            break
        }
        return (aKey, aValue ?? "")
    }
}
