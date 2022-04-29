//
//  GenericError.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/26.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

enum GenericError: CustomNSError, LocalizedError {
    case notRegularFile(url: URL)
    case notDirectory(url: URL)
    case notPackage(url: URL)
    case invalidFilename(name: String)
    
    var errorCode: Int {
        switch self {
        case .notRegularFile:
            return 401
        case .notDirectory:
            return 402
        case .notPackage:
            return 403
        case .invalidFilename:
            return 404
        }
    }
    
    var failureReason: String? {
        switch self {
        case let .notRegularFile(url):
            return String(format: NSLocalizedString("Not a regular file: “%@”.", comment: "GenericError"), url.path)
        case let .notDirectory(url):
            return String(format: NSLocalizedString("Not a directory: “%@”.", comment: "GenericError"), url.path)
        case let .notPackage(url):
            return String(format: NSLocalizedString("Not a package: “%@”.", comment: "GenericError"), url.path)
        case let .invalidFilename(name):
            return String(format: NSLocalizedString("Invalid filename: “%@”.", comment: "GenericError"), name)
        }
    }
}
