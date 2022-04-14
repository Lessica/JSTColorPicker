//
//  GenericError.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/26.
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
            return 501
        case .notDirectory:
            return 502
        case .notPackage:
            return 503
        case .invalidFilename:
            return 504
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
