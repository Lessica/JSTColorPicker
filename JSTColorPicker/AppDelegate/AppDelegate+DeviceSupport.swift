//
//  AppDelegate+DeviceSupport.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/4/15.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa
import Combine
import OMGHTTPURLRQ
import PromiseKit
import PMKFoundation

extension AppDelegate {
    
    static var deviceSupportLocalRootURL: URL = {
        let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )
        .first!
        .appendingPathComponent(Bundle.main.bundleIdentifier!)
        .appendingPathComponent("DeviceSupport")

        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        return url
    }()
    
    private static var deviceSupportRemoteRootURL: URL = {
        let urlString = Bundle.main.object(forInfoDictionaryKey: "SUDeviceSupportRootURL") as! String
        return URL(string: urlString)!
    }()
    
    private static func localDeviceSupportResource(forProductVersion productVersion: String) -> DeviceSupportResource {
        let productVersionArr = productVersion.split(separator: ".")
        let productVersionObj = OperatingSystemVersion(
            majorVersion: productVersionArr.count > 0 ? Int(productVersionArr[0]) ?? 0 : 0,
            minorVersion: productVersionArr.count > 1 ? Int(productVersionArr[1]) ?? 0 : 0,
            patchVersion: productVersionArr.count > 2 ? Int(productVersionArr[2]) ?? 0 : 0
        )
        let deviceSupportVersionURL = deviceSupportLocalRootURL
            .appendingPathComponent("\(productVersionObj.majorVersion).\(productVersionObj.minorVersion)")
        return DeviceSupportResource(
            location: .local,
            productVersion: productVersion,
            developerDiskImageURL: deviceSupportVersionURL.appendingPathComponent("DeveloperDiskImage.dmg"),
            developerDiskImageSignatureURL: deviceSupportVersionURL.appendingPathComponent("DeveloperDiskImage.dmg.signature")
        )
    }
    
    private static func remoteDeviceSupportResource(forProductVersion productVersion: String) -> DeviceSupportResource {
        let productVersionArr = productVersion.split(separator: ".")
        let productVersionObj = OperatingSystemVersion(
            majorVersion: productVersionArr.count > 0 ? Int(productVersionArr[0]) ?? 0 : 0,
            minorVersion: productVersionArr.count > 1 ? Int(productVersionArr[1]) ?? 0 : 0,
            patchVersion: productVersionArr.count > 2 ? Int(productVersionArr[2]) ?? 0 : 0
        )
        let deviceSupportVersionURL = deviceSupportRemoteRootURL
            .appendingPathComponent("\(productVersionObj.majorVersion).\(productVersionObj.minorVersion)")
        return DeviceSupportResource(
            location: .remote,
            productVersion: productVersion,
            developerDiskImageURL: deviceSupportVersionURL.appendingPathComponent("DeveloperDiskImage.dmg"),
            developerDiskImageSignatureURL: deviceSupportVersionURL.appendingPathComponent("DeveloperDiskImage.dmg.signature")
        )
    }
    
    // MARK: - Device Action: Download Device Support Resources
    
    private func promiseDownloadDeviceSupportResource(_ resource: DeviceSupportResource) -> Promise<DeviceSupportResource>
    {
        return Promise<DeviceSupportResource> { seal in
            after(.seconds(600)).done {
                seal.reject(XPCError.timeout)
            }
            
            let targetResource = AppDelegate
                .localDeviceSupportResource(forProductVersion: resource.productVersion)
            
            let signatureRequest = try OMGHTTPURLRQ.get(
                resource.developerDiskImageSignatureURL.absoluteString, nil) as URLRequest
            let signatureTask = self.remoteURLSession.downloadTask(
                .promise,
                with: signatureRequest,
                to: targetResource.developerDiskImageSignatureURL
            )
            
            let mainRequest = try OMGHTTPURLRQ.get(
                resource.developerDiskImageURL.absoluteString, nil) as URLRequest
            let mainTask = self.remoteURLSession.downloadTask(
                .promise,
                with: mainRequest,
                to: targetResource.developerDiskImageURL
            )
            
            signatureTask.then({
                (saveLocation: URL, response: URLResponse) ->
                Promise<(saveLocation: URL, response: URLResponse)> in
                
                debugPrint(saveLocation)
                return mainTask
            }).done({
                (saveLocation: URL, response: URLResponse) in
                
                debugPrint(saveLocation)
                seal.fulfill(targetResource)
            }).catch {
                
                seal.reject($0)
            }
        }
    }
    
    @objc func downloadDeviceSupport(_ sender: Any?, forDeviceDictionary deviceDict: [String: String]) {
        guard !self.isDownloadingDeviceSupport else { return }
        self.isDownloadingDeviceSupport = true
        
        guard let windowController = firstRespondingWindowController
        else {
            self.isDownloadingDeviceSupport = false
            return
        }
        
        guard let deviceVersion = deviceDict["version"]
        else {
            self.isDownloadingDeviceSupport = false
            return
        }
        
        let loadingAlert = NSAlert()
        loadingAlert.addButton(withTitle: NSLocalizedString("Cancel", comment: "downloadDeviceSupport(_:forDeviceDictionary:)"))
        loadingAlert.alertStyle = .informational
        loadingAlert.buttons.first?.isHidden = true
        let loadingIndicator = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 24.0, height: 24.0))
        loadingIndicator.style = .spinning
        loadingIndicator.startAnimation(nil)
        loadingAlert.accessoryView = loadingIndicator
        loadingAlert.messageText = NSLocalizedString("Download Missing Driver", comment: "downloadDeviceSupport(_:forDeviceDictionary:)")
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = true
        formatter.zeroPadsFractionDigits = true
        let downloadProxy = self.remoteURLSessionDownloadProxy
        let downloadObservers: [AnyCancellable] = [
            downloadProxy.$downloadState.sink(receiveValue: { context in
                if let context = context {
                    loadingAlert.informativeText = String(
                        format: "%@\n%@ of %@, %.2f%%",
                        context.currentURL.lastPathComponent,
                        formatter.string(fromByteCount: context.totalBytesWritten),
                        formatter.string(fromByteCount: context.totalBytesExpectedToWrite),
                        Double(context.totalBytesWritten) / Double(context.totalBytesExpectedToWrite)
                    )
                }
            }),
            downloadProxy.$currentError.sink(receiveValue: { error in
                if let error = error {
                    loadingAlert.informativeText = error.localizedDescription
                }
            }),
        ]
        
        
        let pendingResource = AppDelegate.remoteDeviceSupportResource(forProductVersion: deviceVersion)
        firstly { [unowned self] () -> Promise<DeviceSupportResource> in
            loadingAlert.messageText = NSLocalizedString("Connect to server", comment: "downloadDeviceSupport(_:forDeviceDictionary:)")
            loadingAlert.informativeText = String(format: NSLocalizedString("Establish connection to remote server “%@”…", comment: "downloadDeviceSupport(_:forDeviceDictionary:)"), AppDelegate.deviceSupportRemoteRootURL.host!)
            windowController.showSheet(loadingAlert) { [unowned self] resp in
                if resp == .cancel {
                    // cancel last download task if exists
                    self.remoteURLSessionDownloadProxy.lastDownloadTask?.cancel()
                }
            }
            return promiseDownloadDeviceSupportResource(pendingResource)
        }.done { [unowned self] (resource: DeviceSupportResource) in
            // downloaded successfully
            let alert = NSAlert()
            alert.messageText = NSLocalizedString(
                "Driver Downloaded",
                comment: "downloadDeviceSupport(_:forDeviceDictionary:)"
            )
            alert.informativeText = String(
                format: NSLocalizedString(
                    "Developer Disk Image for iOS %@ has been downloaded, click “Continue” to take screenshot again.",
                    comment: "downloadDeviceSupport(_:forDeviceDictionary:)"
                ),
                deviceVersion
            )
            alert.addButton(withTitle: NSLocalizedString("Continue", comment: "downloadDeviceSupport(_:forDeviceDictionary:)"))
            alert.addButton(withTitle: NSLocalizedString("Later", comment: "downloadDeviceSupport(_:forDeviceDictionary:)"))
            windowController.showSheet(alert) { resp in
                if resp == .alertFirstButtonReturn {
                    self.takeScreenshot(sender)
                }
            }
        }.catch { [unowned self] err in
            // failed to download
            if self.applicationCheckScreenshotHelper().exists {
                DispatchQueue.main.async {
                    let alert = NSAlert(error: err)
                    windowController.showSheet(alert, completionHandler: nil)
                }
            }
        }.finally { [unowned self] in
            // do nothing
            downloadObservers.forEach({ $0.cancel() })
            self.isDownloadingDeviceSupport = false
        }
    }
}
