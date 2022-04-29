//
//  AppleDevice.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/14/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation
import PromiseKit

@objc
extension AppleDevice {
    
    @objc
    @discardableResult
    func pair(_ completion: JSTScreenshotHandler) -> Bool {
        return PairHelper.pairDevice(
            name,
            udid,
            isNetworkDevice: type == JSTDeviceTypeNetwork,
            performWirelessPairing: false,
            completion: completion
        )
    }
    
    @objc
    @discardableResult
    func mount(_ completion: JSTScreenshotHandler) -> Bool {
        return MountHelper.mountDevice(
            name,
            udid,
            productVersion: productVersion,
            isNetworkDevice: type == JSTDeviceTypeNetwork,
            completion: completion
        )
    }
}
