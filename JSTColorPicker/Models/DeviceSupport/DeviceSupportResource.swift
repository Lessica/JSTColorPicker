//
//  DeviceSupportResource.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/4/15.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

struct DeviceSupportResource: Codable {
    
    enum ResourceLocation: String, Codable {
        case local
        case remote
    }
    
    let location: ResourceLocation
    let productVersion: String
    let developerDiskImageURL: URL
    let developerDiskImageSignatureURL: URL
    
    func checkResourceIsReachable() throws -> Bool {
        let reachable1 = try developerDiskImageURL.checkResourceIsReachable()
        let reachable2 = try developerDiskImageSignatureURL.checkResourceIsReachable()
        return reachable1 && reachable2
    }
    
    func removeFromLocalStorage() throws {
        try FileManager.default.removeItem(
            at: developerDiskImageSignatureURL)
        try FileManager.default.removeItem(
            at: developerDiskImageURL)
        try FileManager.default.removeItem(
            at: developerDiskImageURL.deletingLastPathComponent())
    }
}
