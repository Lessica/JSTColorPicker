//
//  AndroidDevice.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/12/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import PromiseKit

@objc
final class AndroidDevice: JSTDevice, JSTPairedDevice {

    var udid: String

    init?(udid: String, type: String) {
        self.udid = udid
        super.init(
            base: udid,
            name: AdbHelper.fetchDeviceName(udid),
            model: "Android",
            type: type,
            version: AdbHelper.fetchDeviceVersion(udid)
        )
    }

    override var description: String {
        return String(
            format: "<%@: [%@/%@/%@/%@/%@]>",
            String(describing: AndroidDevice.self),
            type.uppercased(),
            name,
            udid,
            model,
            version
        )
    }

    override func takeScreenshot(completionHandler completion: @escaping JSTScreenshotHandler) {
        let deviceId = self.base
        AdbHelper.promiseCreateDirectoryForScreenCapture(deviceId)
            .then { AdbHelper.promiseScreenCapture(deviceId, to: $0) }
            .then { AdbHelper.promisePullRemoteFile(deviceId, from: $0) }
            .then { AdbHelper.promiseReadLocalFile($0) }
            .then { data -> Promise<Void> in
                completion(data, nil)
                return Promise<Void>()
            }
            .catch { completion(nil, $0) }
    }
}
