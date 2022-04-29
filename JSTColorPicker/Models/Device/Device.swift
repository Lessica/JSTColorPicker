//
//  Device.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/6/11.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

typealias DeviceType = String

enum DeviceDownloadType {
    case xpc
    case dataTask
}

protocol Device {
    var uniqueIdentifier: String { get }
    var title: String { get }
    var subtitle: String { get }
    var type: DeviceType { get }
}
