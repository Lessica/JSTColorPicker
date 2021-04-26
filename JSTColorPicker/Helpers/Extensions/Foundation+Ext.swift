//
//  Foundation+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

extension String {
    
    func leftPadding(to length: Int, with character: Character) -> String {
        if length <= self.count {
            return String(self)
        }
        let newLength = self.count
        if newLength < length {
            return String(repeatElement(character, count: length - newLength)) + self
        } else {
            let idx = self.index(self.startIndex, offsetBy: newLength - length)
            return String(self[..<idx])
        }
    }
    
    // Modified from the DragonCherry extension - https://github.com/DragonCherry/VersionCompare
    private func compare(toVersion targetVersion: String) -> ComparisonResult {
        let versionDelimiter = "."
        var result: ComparisonResult = .orderedSame
        var versionComponents = components(separatedBy: versionDelimiter)
        var targetComponents = targetVersion.components(separatedBy: versionDelimiter)
        
        while versionComponents.count < targetComponents.count {
            versionComponents.append("0")
        }
        while targetComponents.count < versionComponents.count {
            targetComponents.append("0")
        }
        
        for (version, target) in zip(versionComponents, targetComponents) {
            result = version.compare(target, options: .numeric)
            if result != .orderedSame {
                break
            }
        }
        
        return result
    }
    
    func isVersion(equalTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedSame }
    func isVersion(greaterThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedDescending }
    func isVersion(greaterThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedAscending }
    func isVersion(lessThan targetVersion: String) -> Bool { return compare(toVersion: targetVersion) == .orderedAscending }
    func isVersion(lessThanOrEqualTo targetVersion: String) -> Bool { return compare(toVersion: targetVersion) != .orderedDescending }
    
}

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
    func chunked(into size: Int) -> [[Element]] {
        if count <= size {
            return [Array(self)]
        }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

extension Array {
    func filterDuplicates(includeElement: (_ lhs: Element, _ rhs: Element) -> Bool) -> [Element] {
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
    func insertionIndexOf(_ elem: Element, isOrderedBefore: (Element, Element) -> Bool) -> Int {
        var lo = 0
        var hi = count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if isOrderedBefore(self[mid], elem) {
                lo = mid + 1
            } else if isOrderedBefore(elem, self[mid]) {
                hi = mid - 1
            } else {
                return mid // found at position mid
            }
        }
        return lo // not found, would be inserted at position lo
    }
    mutating func remove(at set: IndexSet) {
        var arr = Swift.Array(enumerated())
        arr.removeAll { set.contains($0.offset) }
        self = arr.map { $0.element }
    }
}

extension Dictionary where Value == Int {
    init<S: Sequence>(counted list: S) where S.Element == Key {
        let ones = repeatElement(1, count: Int.max)
        self.init(zip(list, ones), uniquingKeysWith: +)
    }
}

extension URL {
    /// The time at which the resource was created.
    /// This key corresponds to an Date value, or nil if the volume doesn't support creation dates.
    /// A resource’s creationDateKey value should be less than or equal to the resource’s contentModificationDateKey and contentAccessDateKey values. Otherwise, the file system may change the creationDateKey to the lesser of those values.
    var creation: Date? {
        get {
            return (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
        }
        set {
            var resourceValues = URLResourceValues()
            resourceValues.creationDate = newValue
            try? setResourceValues(resourceValues)
        }
    }
    /// The time at which the resource was most recently modified.
    /// This key corresponds to an Date value, or nil if the volume doesn't support modification dates.
    var contentModification: Date? {
        get {
            return (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
        set {
            var resourceValues = URLResourceValues()
            resourceValues.contentModificationDate = newValue
            try? setResourceValues(resourceValues)
        }
    }
    /// The time at which the resource was most recently accessed.
    /// This key corresponds to an Date value, or nil if the volume doesn't support access dates.
    ///  When you set the contentAccessDateKey for a resource, also set contentModificationDateKey in the same call to the setResourceValues(_:) method. Otherwise, the file system may set the contentAccessDateKey value to the current contentModificationDateKey value.
    var contentAccess: Date? {
        get {
            return (try? resourceValues(forKeys: [.contentAccessDateKey]))?.contentAccessDate
        }
        // Beginning in macOS 10.13, iOS 11, watchOS 4, tvOS 11, and later, contentAccessDateKey is read-write. Attempts to set a value for this file resource property on earlier systems are ignored.
        set {
            var resourceValues = URLResourceValues()
            resourceValues.contentAccessDate = newValue
            try? setResourceValues(resourceValues)
        }
    }

    var isRegularFile: Bool {
        return (try? resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
    }
    
    var isDirectory: Bool {
        return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    var isPackage: Bool {
        return (try? resourceValues(forKeys: [.isPackageKey]))?.isPackage ?? false
    }
}
