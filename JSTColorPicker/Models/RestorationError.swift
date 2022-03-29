//
//  RestorationError.swift
//  JSTColorPicker
//
//  Created by Rachel on 3/29/22.
//  Copyright © 2022 JST. All rights reserved.
//

import Foundation

enum RestorationError: CustomNSError, LocalizedError {
    case noSuchWindow(identifier: String)
    
    var errorCode: Int {
        switch self {
            case .noSuchWindow:
                return 901
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .noSuchWindow(identifier):
                return String(format: NSLocalizedString("No such window: \"%@\".", comment: "RestorationError"), identifier)
        }
    }
}
