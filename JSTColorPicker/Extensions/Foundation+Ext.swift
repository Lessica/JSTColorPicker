//
//  Foundation+Ext.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/4/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

public extension String {
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
}

public extension String {
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

public extension Array {
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
    func chunked(into size: Int) -> [[Element]] {
        if count <= size {
            return [Array(self)]
        }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

public extension Dictionary where Value == Int {
    init<S: Sequence>(counted list: S) where S.Element == Key {
        let ones = repeatElement(1, count: Int.max)
        try! self.init(zip(list, ones), uniquingKeysWith: +)
    }
}
