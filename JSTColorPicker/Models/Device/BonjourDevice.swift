//
//  BonjourDevice.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/6/11.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import Network

struct BonjourDevice: Codable, Hashable, Device {
    internal init(hostName: String, domain: String, name: String, port: Int, txtRecord: [String : String], ipAddresses: [String]) {
        self.hostName = hostName
        self.domain = domain
        self.name = name
        self.port = port
        self.txtRecord = txtRecord
        self.ipAddresses = ipAddresses
    }
    
    let hostName: String
    let domain: String
    let name: String
    let port: Int
    let txtRecord: [String: String]
    let ipAddresses: [String]
    
    internal init(netService: NetService) {
        self.domain = netService.domain
        self.name = netService.name
        self.hostName = netService.hostName ?? ""
        self.port = netService.port
        self.txtRecord = netService.txtRecordDictionary ?? [:]
        self.ipAddresses = netService.ipAddresses.map({
            if let v4Addr = $0 as? IPv4Address {
                var ipAddressBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                _ = v4Addr.rawValue.withUnsafeBytes {
                    inet_ntop(AF_INET, $0.baseAddress!.assumingMemoryBound(to: UInt8.self),
                              &ipAddressBuffer, socklen_t(INET_ADDRSTRLEN))
                }
                let ipAddressString = String.init(cString: ipAddressBuffer)
                precondition(!ipAddressString.hasPrefix("0."))
                return ipAddressString
            }
            else if let v6Addr = $0 as? IPv6Address {
                var ipAddressBuffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                _ = v6Addr.rawValue.withUnsafeBytes {
                    inet_ntop(AF_INET6, $0.baseAddress!.assumingMemoryBound(to: UInt8.self),
                              &ipAddressBuffer, socklen_t(INET6_ADDRSTRLEN))
                }
                let ipAddressString = String.init(cString: ipAddressBuffer)
                return ipAddressString
            }
            return String(describing: $0)
        })
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(hostName)
        hasher.combine(domain)
        hasher.combine(name)
        hasher.combine(port)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.hostName == rhs.hostName && lhs.domain == rhs.domain && lhs.name == rhs.name && lhs.port == rhs.port
    }
    
    static func unresolved(hostName: String) -> BonjourDevice {
        return BonjourDevice(hostName: hostName, domain: "", name: "", port: 0, txtRecord: [:], ipAddresses: [])
    }
    
    var isResolved: Bool {
        ipAddresses.count > 0
    }
    
    static let uniquePrefix: String = "device.bonjour."
    var uniqueIdentifier: String { "\(BonjourDevice.uniquePrefix)\(hostName)" }
    var title: String { name }
    var subtitle: String { ipAddresses.first ?? "Unresolved" }
    var type: DeviceType { JSTDeviceTypeBonjour }
    static let downloadType = DeviceDownloadType.dataTask
}
