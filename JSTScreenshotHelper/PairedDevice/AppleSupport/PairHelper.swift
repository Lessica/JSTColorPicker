//
//  PairHelper.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation
import PromiseKit
import AuxiliaryExecute

@objc
final class PairHelper: NSObject {
    
    static let idevicepair = Bundle.main.url(forAuxiliaryExecutable: "idevicepair")!
    private static let namespace = "PairHelper"
    
    @objc
    static func pairDevice(
        _ name: String,
        _ udid: String,
        isNetworkDevice: Bool = false,
        performWirelessPairing: Bool = false,
        completion: JSTScreenshotHandler
    ) -> Bool {
        
        var command = "\(idevicepair.path) pair -u \(udid)"
        
        if isNetworkDevice {
            command += " -n"
        }
        if performWirelessPairing {
            command += " -w"
        }
#if DEBUG
        command += " -d"
#endif
        
        let result = AuxiliaryExecute.local.bash(command: command, timeout: 5)
        let resultOutput = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSucceed = resultOutput.hasPrefix("SUCC")
        
        completion(nil, NSError(domain: kJSTScreenshotError, code: isSucceed ? 702 : 703, userInfo: [
            NSLocalizedDescriptionKey: String(
                format: "%@\n\n%@",
                resultOutput.replacingOccurrences(of: udid, with: "“\(name)”"),
                isSucceed
                ? String(
                    format: NSLocalizedString("“%@” paired with this host automatically, click “Retry” to continue.", comment: "kJSTScreenshotError"), name
                )
                : String(
                    format: NSLocalizedString("To use “%@” with JSTColorPicker, unlock it and choose to trust this computer when prompted.", comment: "kJSTScreenshotError"), name
                )
            )
        ]))
        
        return isSucceed
    }
}

