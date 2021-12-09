//
//  AdbHelper.swift
//  adbconnect
//
//  Created by Naman Dwivedi on 11/03/21.
//

import Foundation

final class AdbHelper {
    
    let adb = Bundle.main.url(forAuxiliaryExecutable: "adb")
    private static let namespace = "AdbHelper"

    func getDevices() -> [AndroidDevice] {
        let command = "devices -l | awk 'NR>1 {print $1}'"
        let devicesResult = runAdbCommand(command)
        return devicesResult
            .components(separatedBy: .newlines)
            .filter({ (id) -> Bool in
                !id.isEmpty
            })
            .map { (id) -> AndroidDevice in
                AndroidDevice(base: id, name: getDeviceName(deviceId: id), model: "Android", type: JSTDeviceTypeUSB)
            }
    }
    
    func getDeviceName(deviceId: String) -> String {
        let command = "-s " + deviceId + " shell getprop ro.product.model"
        return runAdbCommand(command)
    }
    
    func takeScreenshot(deviceId: String) {
        let time = formattedTime()
        runAdbCommand("-s " + deviceId + " shell screencap -p /sdcard/\(AdbHelper.namespace)_screencap.png")
        runAdbCommand("-s " + deviceId + " pull /sdcard/\(AdbHelper.namespace)_screencap.png ~/Desktop/screen" + time + ".png")
    }
    
    func recordScreen(deviceId: String) {
        let command = "-s " + deviceId + " shell screenrecord /sdcard/\(AdbHelper.namespace)_screenrecord.mp4"
        
        // run record screen in background
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runAdbCommand(command)
        }
    }

    func stopScreenRecording(deviceId: String) {
        let time = formattedTime()
        
        // kill already running screenrecord process to stop recording
        runAdbCommand("-s " + deviceId + " shell pkill -INT screenrecord")
        
        // after killing the screenrecord process,we have to for some time before pulling the file else file stays corrupted
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.runAdbCommand("-s " + deviceId + " pull /sdcard/\(AdbHelper.namespace)_screenrecord.mp4 ~/Desktop/record" + time + ".mp4")
        }
    }
    
    func makeTCPConnection(deviceId: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let deviceIp = self?.getDeviceIp(deviceId: deviceId) {
                let tcpCommand = "-s " + deviceId + " tcpip 5555"
                self?.runAdbCommand(tcpCommand)
                let connectCommand = "-s " + deviceId + " connect " + deviceIp + ":5555"
                self?.runAdbCommand(connectCommand)
            }
        }
    }
    
    func disconnectTCPConnection(deviceId: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runAdbCommand("-s " + deviceId + " disconnect")
        }
    }

    func getDeviceIp(deviceId: String) -> String {
        let command = "-s " + deviceId + " shell ip route | awk '{print $9}'"
        return runAdbCommand(command)
    }
    
    func openDeeplink(deviceId: String, deeplink: String) {
        let command = "-s " + deviceId + " shell am start -a android.intent.action.VIEW -d '\(deeplink)'"
        runAdbCommand(command)
    }
    
    func captureBugReport(deviceId: String) {
        let time = formattedTime()
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.runAdbCommand("-s " + deviceId + " logcat -d > ~/Desktop/\(AdbHelper.namespace)_logcat_\(time).txt")
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        let time = formatter.string(from: Date())
        return time
    }

    @discardableResult
    private func runAdbCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", adb!.path + " " + command]
        task.launchPath = "/bin/sh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        return output
    }
    
}

