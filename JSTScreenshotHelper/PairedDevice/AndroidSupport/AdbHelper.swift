//
//  AdbHelper.swift
//  adbconnect
//
//  Created by Naman Dwivedi on 11/03/21.
//

import Foundation
import PromiseKit
import AuxiliaryExecute

@objc
final class AdbHelper: NSObject {
    
    static let adb = Bundle.main.url(forAuxiliaryExecutable: "adb")!
    private static let namespace = "AdbHelper"
    
    static func fetchDeviceName(_ deviceId: String) -> String {
        let command = "\(adb.path) -s '\(deviceId)' shell getprop ro.product.model"
        return AuxiliaryExecute.local.bash(command: command, timeout: 3).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc
    static func getDevices() -> [AndroidDevice] {
        let command = "\(adb.path) devices -l | awk 'NR>1 {print $1}'"
        let devicesResult = AuxiliaryExecute.local.bash(command: command, timeout: 3).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return devicesResult
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .compactMap { AndroidDevice(udid: $0, type: JSTDeviceTypeUSB) }
    }

    static func promiseCreateDirectoryForScreenCapture(_ deviceId: String) -> Promise<URL> {
        let savingDirectory = URL(fileURLWithPath: "/sdcard/Pictures/JSTColorPicker")
        return Promise<URL> { seal in
            AuxiliaryExecute.promiseBash(
                command: "\(adb.path) -s '\(deviceId)' shell mkdir -p '\(savingDirectory.path)'",
                environment: [:],
                timeout: 60
            ).then { result -> Promise<Void> in
                if result.exitCode == 0 {
                    seal.fulfill(savingDirectory)
                } else {
                    seal.reject(CommandError.nonZeroExitCode(code: result.exitCode, reason: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                return Promise<Void>()
            }.catch { err in
                seal.reject(err)
            }
        }
    }

    private static var formattedNow: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: Date())
    }

    static func promiseScreenCapture(_ deviceId: String, to url: URL) -> Promise<URL> {
        let destURL = url.appendingPathComponent("\(AdbHelper.namespace)_screencap_\(formattedNow).png")
        return Promise<URL> { seal in
            AuxiliaryExecute.promiseBash(
                command: "\(adb.path) -s '\(deviceId)' shell screencap -p '\(destURL.path)'",
                environment: [:],
                timeout: 60
            ).then { result -> Promise<Void> in
                if result.exitCode == 0 {
                    seal.fulfill(destURL)
                } else {
                    seal.reject(CommandError.nonZeroExitCode(code: result.exitCode, reason: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                return Promise<Void>()
            }.catch { err in
                seal.reject(err)
            }
        }
    }

    static func promisePullRemoteFile(_ deviceId: String, from url: URL) -> Promise<URL> {
        let tmpParent = FileManager.default.temporaryDirectory.appendingPathComponent(namespace)
        try? FileManager.default.createDirectory(at: tmpParent, withIntermediateDirectories: true, attributes: nil)
        let tmpURL = tmpParent.appendingPathComponent(UUID().uuidString, isDirectory: false).appendingPathExtension("png")
        return Promise<URL> { seal in
            AuxiliaryExecute.promiseBash(
                command: "\(adb.path) -s '\(deviceId)' pull '\(url.path)' '\(tmpURL.path)'",
                environment: [:],
                timeout: 60
            ).then { result -> Promise<Void> in
                if result.exitCode == 0 {
                    seal.fulfill(tmpURL)
                } else {
                    seal.reject(CommandError.nonZeroExitCode(code: result.exitCode, reason: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                return Promise<Void>()
            }.catch { err in
                seal.reject(err)
            }
        }
    }

    static func promiseReadLocalFile(_ url: URL) -> Promise<Data> {
        return Promise<Data> { seal in
            do {
                seal.fulfill(try Data(contentsOf: url))
            } catch {
                seal.reject(error)
            }
        }
    }
    
}

