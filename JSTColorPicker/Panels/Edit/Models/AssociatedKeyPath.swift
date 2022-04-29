//
//  AssociatedKeyPath.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/3/23.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

@objc
final class AssociatedKeyPath: NSObject, NSCopying {
    
    internal init(
        name: String,
        type: AssociatedKeyPath.ValueType,
        value: Any? = nil,
        options: [String]? = nil,
        helpText: String? = nil,
        isEditable: Bool = true
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.options = options
        self.helpText = helpText
        self.isEditable = isEditable
        super.init()
        updateDynamicVariables()
        allowsKVONotification = true
    }

    static var initializedOrder = 0

    override init() {
        AssociatedKeyPath.initializedOrder += 1
        name = "keyPath #\(AssociatedKeyPath.initializedOrder)"
        type = .String
        value = type.defaultValue
        options = nil
        helpText = nil
        isEditable = true
        super.init()
        updateDynamicVariables()
        allowsKVONotification = true
    }

    @objc
    enum ValueType: Int {
        
        case String = 0 // text input
        case Boolean // checkbox
        case Integer // text input
        case Decimal // text input
        case Nil // nothing

        init(string: Field.StringValueType) {
            switch string {
            case .String:
                self = .String
            case .Boolean:
                self = .Boolean
            case .Integer:
                self = .Integer
            case .Decimal:
                self = .Decimal
            case .Nil:
                self = .Nil
            }
        }
        
        var defaultValue: Any?
        {
            switch self {
            case .String:
                return ""
            case .Boolean:
                return false
            case .Integer:
                return 0
            case .Decimal:
                return 0.0
            case .Nil:
                return nil
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
    @objc dynamic var isEditable: Bool
    
    @objc dynamic var hasOptions = false
    @objc dynamic var isCheckboxValue = false
    @objc dynamic var isTextInputValue = false
    @objc dynamic var isTextInputIntegerValue = false
    @objc dynamic var isTextInputDecimalValue = false

    func copy(with zone: NSZone? = nil) -> Any {
        return AssociatedKeyPath(
            name: name,
            type: type,
            value: value,
            options: options,
            helpText: helpText,
            isEditable: isEditable
        )
    }

    private func updateDynamicVariables() {
        hasOptions = options?.count ?? 0 > 0
        switch type {
        case .String:
            isCheckboxValue = false
            isTextInputValue = !hasOptions
            isTextInputIntegerValue = false
            isTextInputDecimalValue = false
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
        isEditable = { self.isEditable }()
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
