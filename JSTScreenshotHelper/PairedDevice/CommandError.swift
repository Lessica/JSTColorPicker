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
    
    var errorCode: Int {
        switch self {
            case .nonZeroExitCode:
                return 701
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .nonZeroExitCode(code, reason):
                return String(format: NSLocalizedString("Command exited with non-zero status code: “%ld”, error reason: %@.", comment: "CommandError"), code, reason)
        }
    }
}

