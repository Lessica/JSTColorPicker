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
    
    private static let imageName = "DeveloperDiskImage.dmg"
    private static let signatureName = "DeveloperDiskImage.dmg.signature"
    
    private static func isValidDeviceSupportSubdirectory(_ parentURL: URL) -> Bool {
        guard parentURL.isDirectory else {
            return false
        }
        let childURLs = [
            parentURL.appendingPathComponent(MountHelper.imageName),
            parentURL.appendingPathComponent(MountHelper.signatureName),
        ]
        return childURLs.allSatisfy({ $0.isRegularFile })
    }
    
    @objc
    static func mountDevice(
        _ name: String,
        _ udid: String,
        productVersion: String,
        isNetworkDevice: Bool = false,
        completion: JSTScreenshotHandler
    ) -> Bool {
        
        // target version
        let productVersionArr = productVersion.split(separator: ".")
        let productVersionObj = OperatingSystemVersion(
            majorVersion: productVersionArr.count > 0 ? Int(productVersionArr[0]) ?? 0 : 0,
            minorVersion: productVersionArr.count > 1 ? Int(productVersionArr[1]) ?? 0 : 0,
            patchVersion: productVersionArr.count > 2 ? Int(productVersionArr[2]) ?? 0 : 0
        )
        var targetVersion = "\(productVersionObj.majorVersion).\(productVersionObj.minorVersion)"
        var deviceSupportURL: URL?
        var xcodeURLs = Set<URL>()
        
        // cache url
        let cacheURL = URL(fileURLWithPath: GetJSTColorPickerDeviceSupportPath())
        if cacheURL.isDirectory {
            xcodeURLs.insert(cacheURL)
        }
        
        // active xcode url
        let deviceSupportPrefix = "Platforms/iPhoneOS.platform/DeviceSupport"
        var xcodePath = AuxiliaryExecute.local
            .bash(command: "xcode-select -p")
            .stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !xcodePath.starts(with: "/") {
            xcodePath = "/Applications/Xcode.app/Contents/Developer"
        }
        
        // possible xcode urls
        let activeXcodeURL = URL(fileURLWithPath: xcodePath)
            .appendingPathComponent(deviceSupportPrefix, isDirectory: true)
        if activeXcodeURL.isDirectory {
            xcodeURLs.insert(activeXcodeURL)
        }
        if let possibleXcodeURLs = try? FileManager.default
            .contentsOfDirectory(
                at: URL(fileURLWithPath: "/Applications"),
                includingPropertiesForKeys: [.isPackageKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
            )
            .filter({ $0.lastPathComponent.hasPrefix("Xcode") && $0.lastPathComponent.hasSuffix(".app") })
            .filter({ $0.isPackage })
            .map({ $0.appendingPathComponent("Contents/Developer", isDirectory: true) })
            .map({ $0.appendingPathComponent(deviceSupportPrefix, isDirectory: true) })
            .filter({ $0.isDirectory })
        {
            xcodeURLs.formUnion(possibleXcodeURLs)
        }
        
        // match target version exactly
        let sortedXcodeURLs = xcodeURLs.sorted(by: {
            var compareResult = ComparisonResult.orderedSame
            if let firstModificationDate = $0.contentModification,
               let lastModificationDate = $1.contentModification
            {
                compareResult = firstModificationDate.compare(lastModificationDate)
            }
            if compareResult == .orderedSame {
                return $0.pathComponents[1].localizedStandardCompare($1.pathComponents[1]) == .orderedDescending
            }
            return compareResult == .orderedDescending
        })
        for xcodeURL in sortedXcodeURLs {
            let possibleDeviceSupportURL = xcodeURL.appendingPathComponent(targetVersion, isDirectory: true)
            if MountHelper.isValidDeviceSupportSubdirectory(possibleDeviceSupportURL) {
                deviceSupportURL = possibleDeviceSupportURL
                break
            }
        }
        
        // no exact match, find the best version
        if deviceSupportURL == nil {
            let possibleDeviceSupportURLs = xcodeURLs
                .compactMap({
                    try? FileManager.default.contentsOfDirectory(
                        at: $0,
                        includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                        options:[.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
                    )
                })
                .flatMap({ $0 })
                .filter({ $0.isDirectory })
                .sorted(by: {
                    let compareResult = $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent)
                    if compareResult == .orderedSame,
                       let firstModificationDate = $0.contentModification,
                       let lastModificationDate = $1.contentModification
                    {
                        return firstModificationDate.compare(lastModificationDate) == .orderedAscending
                    }
                    return compareResult == .orderedAscending
                })
            let possibleDeviceSupportNames = possibleDeviceSupportURLs.map({ $0.lastPathComponent })
            if var targetIndex = possibleDeviceSupportNames.firstIndex(where: { targetVersion.localizedStandardCompare($0) == .orderedAscending }) {
                if targetIndex == 0 {
                    targetIndex += 1
                } else {
                    // use previous version by default
                    targetIndex -= 1
                }
                let possibleDeviceSupportURL = possibleDeviceSupportURLs[targetIndex]
                if let possibleMajorVersionString = possibleDeviceSupportURL.lastPathComponent.split(separator: ".").first,
                   let possibleMajorVersion = Int(possibleMajorVersionString),
                   possibleMajorVersion == productVersionObj.majorVersion
                {
                    if MountHelper.isValidDeviceSupportSubdirectory(possibleDeviceSupportURL) {
                        targetVersion = possibleDeviceSupportNames[targetIndex]
                        deviceSupportURL = possibleDeviceSupportURL
                    }
                }
            }
        }
        
        guard let deviceSupportURL = deviceSupportURL else {
            completion(nil, NSError(domain: kJSTScreenshotError, code: CommandError.missingMountResources.errorCode, userInfo: [
                NSLocalizedDescriptionKey: String(
                    format: "%@\n\n%@",
                    String(format: NSLocalizedString("Cannot locate the Developer Disk Image and its signature for “%@” with iOS version “%@”.", comment: "kJSTScreenshotError"), name, productVersion),
                    String(format: NSLocalizedString("To use “%@” with JSTColorPicker, install the latest Xcode or mount the Developer Disk Image to your iOS device manually. Or, click “Download” to download missing driver from our CDN.", comment: "kJSTScreenshotError"), name)
                )
            ]))
            return false
        }
        
        let path1 = deviceSupportURL.appendingPathComponent(MountHelper.imageName, isDirectory: true)
            .path.replacingOccurrences(of: "'", with: "'\''")
        let path2 = deviceSupportURL.appendingPathComponent(MountHelper.signatureName, isDirectory: true)
            .path.replacingOccurrences(of: "'", with: "'\''")
        
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
        completion(nil, NSError(domain: kJSTScreenshotError, code: isSucceed ? CommandError.retryMountSucceed.errorCode : CommandError.mountFailed.errorCode, userInfo: [
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

