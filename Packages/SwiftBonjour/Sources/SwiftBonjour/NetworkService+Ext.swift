//
//  NetworkService+Ext.swift
//  SwiftBonjour
//
//  Created by Rachel on 2021/5/18.
//

import Foundation
import Network

extension NetService {
    public class func dictionary(fromTXTRecord data: Data) -> [String: String] {
        return NetService.dictionary(fromTXTRecord: data).mapValues { data in
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    public class func data(fromTXTRecord data: [String: String]) -> Data {
        return NetService.data(fromTXTRecord: data.mapValues { $0.data(using: .utf8) ?? Data() })
    }

    public func setTXTRecord(dictionary: [String: String]?){
        guard let dictionary = dictionary else {
            self.setTXTRecord(nil)
            return
        }
        self.setTXTRecord(NetService.data(fromTXTRecord: dictionary))
    }

    public var txtRecordDictionary: [String: String]? {
        guard let data = self.txtRecordData() else { return nil }
        return NetService.dictionary(fromTXTRecord: data)
    }
    
    @available(macOS 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    public var ipAddresses: [IPAddress] {
        var ipAddrs = [IPAddress]()
        guard let addresses = addresses else {
            return ipAddrs
        }
        for sockAddrData in addresses {
            if sockAddrData.count == MemoryLayout<sockaddr_in>.size {
                let sockAddrBytes = UnsafeMutableBufferPointer<sockaddr_in>.allocate(capacity: sockAddrData.count)
                precondition(sockAddrData.copyBytes(to: sockAddrBytes) == MemoryLayout<sockaddr_in>.size)
                if var sAddr = sockAddrBytes.baseAddress?.pointee.sin_addr.s_addr {
                    let isLocalLinkAddr = (sAddr & 0x0000ffff == 0x0000fea9) || ((sAddr | 0x0000ffff) >> 16 == 0)
                    if !isLocalLinkAddr
                    {
                        if let ipAddr = IPv4Address(Data(bytes: &sAddr, count: MemoryLayout<in_addr_t>.size))
                        {
                            ipAddrs.append(ipAddr)
                        }
                    }
                }
            } else if sockAddrData.count == MemoryLayout<sockaddr_in6>.size {
                let sockAddrBytes = UnsafeMutableBufferPointer<sockaddr_in6>.allocate(capacity: sockAddrData.count)
                precondition(sockAddrData.copyBytes(to: sockAddrBytes) == MemoryLayout<sockaddr_in6>.size)
                // Get the sin6_addr part of the sockaddr as UInt8 "array":
                if var s6_addr = sockAddrBytes.baseAddress?.pointee.sin6_addr.__u6_addr.__u6_addr8 {
                    // Check for link-local address:
                    let isLocalLinkAddr = (s6_addr.0 == 0xfe && (s6_addr.1 & 0xc0) == 0x80)
                    if !isLocalLinkAddr
                    {
                        if let ipAddr = IPv6Address(Data(bytes: &s6_addr, count: MemoryLayout<in6_addr_t>.size))
                        {
                            ipAddrs.append(ipAddr)
                        }
                    }
                }
            }
        }
        return ipAddrs
    }
}
