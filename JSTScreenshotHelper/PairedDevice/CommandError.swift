//
//  CommandError.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

enum CommandError: CustomNSError, LocalizedError {
    case nonZeroExitCode(code: Int, reason: String)
    case retryPairSucceed
    case pairFailed
    case retryMountSucceed
    case mountFailed
    case missingMountResources
    
    var errorCode: Int {
        switch self {
        case .nonZeroExitCode:
            return 701
        case .retryPairSucceed:
            return 702
        case .pairFailed:
            return 703
        case .retryMountSucceed:
            return 704
        case .mountFailed:
            return 705
        case .missingMountResources:
            return 707
        }
    }
    
    var failureReason: String? {
        switch self {
        case let .nonZeroExitCode(code, reason):
            return String(format: NSLocalizedString("Command exited with non-zero status code: “%ld”, error reason: %@.", comment: "CommandError"), code, reason)
        default:
            return nil
        }
    }
}

