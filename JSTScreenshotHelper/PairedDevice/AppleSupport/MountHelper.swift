//
//  MountHelper.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation
import PromiseKit
import AuxiliaryExecute

@objc
final class MountHelper: NSObject {
    
    static let ideviceimagemounter = Bundle.main.url(forAuxiliaryExecutable: "ideviceimagemounter")!
    private static let namespace = "MountHelper"
    
    @objc
    static func mountDevice(
        _ name: String,
        _ udid: String,
        productVersion: String,
        isNetworkDevice: Bool = false,
        completion: JSTScreenshotHandler
    ) -> Bool {
        
        var xcodePath = AuxiliaryExecute.local.bash(command: "xcode-select -p").stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !xcodePath.starts(with: "/") {
            xcodePath = "/Applications/Xcode.app/Contents/Developer"
        }
        
        let productVersionArr = productVersion.split(separator: ".")
        let productVersionObj = OperatingSystemVersion(
            majorVersion: productVersionArr.count > 0 ? Int(productVersionArr[0]) ?? 0 : 0,
            minorVersion: productVersionArr.count > 1 ? Int(productVersionArr[1]) ?? 0 : 0,
            patchVersion: productVersionArr.count > 2 ? Int(productVersionArr[2]) ?? 0 : 0
        )
        
        let deviceSupportURL = URL(fileURLWithPath: xcodePath)
            .appendingPathComponent(
                "Platforms/iPhoneOS.platform/DeviceSupport/\(productVersionObj.majorVersion).\(productVersionObj.minorVersion)")
        let deviceSupportURLs = [
            deviceSupportURL.appendingPathComponent("DeveloperDiskImage.dmg"),
            deviceSupportURL.appendingPathComponent("DeveloperDiskImage.dmg.signature"),
        ]
        
        let isDeviceSupportReachable = deviceSupportURLs.allSatisfy({
            (try? $0.checkResourceIsReachable()) ?? false
        })
        
        if !isDeviceSupportReachable {
            completion(nil, NSError(domain: kJSTScreenshotError, code: 705, userInfo: [
                NSLocalizedDescriptionKey: String(
                    format: "%@\n\n%@",
                    String(format: NSLocalizedString("Cannot locate the Developer Disk Image and its signature for “%@” with iOS version “%@”.", comment: "kJSTScreenshotError"), name, productVersion),
                    String(format: NSLocalizedString("To use “%@” with JSTColorPicker, install the latest Xcode or mount the Developer Disk Image to your iOS device manually.", comment: "kJSTScreenshotError"), name)
                )
            ]))
            return false
        }
        
        let path1 = deviceSupportURLs[0].path.replacingOccurrences(of: "'", with: "'\''")
        let path2 = deviceSupportURLs[1].path.replacingOccurrences(of: "'", with: "'\''")
        
        var command = "\(ideviceimagemounter.path) '\(path1)' '\(path2)' -u \(udid)"
        
        if isNetworkDevice {
            command += " -n"
        }
#if DEBUG
        command += " -d"
#endif
        
        let result = AuxiliaryExecute.local.bash(command: command, timeout: 5)
        
        let resultError = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let resultOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let isSucceed = resultOutput.contains("Done") || resultOutput.contains("done")
        completion(nil, NSError(domain: kJSTScreenshotError, code: isSucceed ? 704 : 705, userInfo: [
            NSLocalizedDescriptionKey: String(
                format: "%@\n\n%@",
                resultError.count > 0 ? resultError : resultOutput,
                isSucceed
                ? String(
                    format: NSLocalizedString("Developer Disk Image mounted to “%@” automatically, click “Retry” to continue.", comment: "kJSTScreenshotError"), name
                )
                : String(
                    format: NSLocalizedString("To use “%@” with JSTColorPicker, install the latest Xcode or mount the Developer Disk Image to your iOS device manually.", comment: "kJSTScreenshotError"), name
                )
            )
        ]))
        return isSucceed
    }
}

