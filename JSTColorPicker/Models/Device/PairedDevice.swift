//
//  PairedDevice.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/6/11.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

struct PairedDevice: Codable, Hashable, Device {
    let udid: String
    let name: String
    let type: DeviceType
    let model: String
    let version: String
    
    static let uniquePrefix: String = "device.paired."
    var uniqueIdentifier: String { "\(PairedDevice.uniquePrefix)\(udid)" }
    var title: String { name }
    var subtitle: String { udid }
    static let downloadType = DeviceDownloadType.xpc
}
