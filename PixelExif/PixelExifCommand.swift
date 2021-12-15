//
//  PixelExifCommand.swift
//  PixelExif
//
//  Created by Rachel on 2021/12/15.
//  Copyright © 2021 JST. All rights reserved.
//

import ArgumentParser
import Foundation
import SwiftExif
import ImageIO


@main
struct PixelExifCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "pixelexif",
        abstract: "A wrapping executable for SwiftExif, which is a wrapping library for libexif and libiptcdata for Swift to provide a JPEG metadata extraction on Linux and macOS.",
        version: "2.10",
        subcommands: [
            PixelExifEnteries.self,
            PixelExifRawEnteries.self,
            PixelIptcEnteries.self,
            PiexlExportCommand.self,
        ]
    )
}

protocol JsonifyCommand: ParsableCommand {
    var jsonify: Bool { get set }
}

struct PixelExifEnteries: JsonifyCommand {
    static var configuration = CommandConfiguration(
        commandName: "enteries",
        abstract: "read and print exif dictionary of specific image in a human-readable format"
    )
    
    @Argument(help: "path of the image")
    var imagePath: String
    
    @Flag(help: "output as json")
    var jsonify: Bool = false
    
    func run() throws {
        let exifImage = SwiftExif.Image(imagePath: URL(fileURLWithPath: imagePath))
        let exifDict = exifImage.Exif()
        guard exifDict.count > 0 else {
            throw ExitCode.failure
        }
        if !jsonify {
            dump(exifDict)
        } else {
            print(
                String(
                    data: try JSONSerialization.data(withJSONObject: exifDict, options: [.sortedKeys, .prettyPrinted]),
                    encoding: .utf8
                ) ?? ""
            )
        }
    }
}

struct PixelExifRawEnteries: JsonifyCommand {
    static var configuration = CommandConfiguration(
        commandName: "raw_enteries",
        abstract: "read and print exif dictionary of specific image in raw format"
    )
    
    @Argument(help: "path of the image")
    var imagePath: String
    
    @Flag(help: "output as json")
    var jsonify: Bool = false
    
    func run() throws {
        let exifImage = SwiftExif.Image(imagePath: URL(fileURLWithPath: imagePath))
        let exifDict = exifImage.ExifRaw()
        guard exifDict.count > 0 else {
            throw ExitCode.failure
        }
        if !jsonify {
            dump(exifDict)
        } else {
            print(
                String(
                    data: try JSONSerialization.data(withJSONObject: exifDict, options: [.sortedKeys, .prettyPrinted]),
                    encoding: .utf8
                ) ?? ""
            )
        }
    }
}

struct PixelIptcEnteries: JsonifyCommand {
    static var configuration = CommandConfiguration(
        commandName: "iptc_enteries",
        abstract: "read and print iptc dictionary of specific image in a human-readable format"
    )
    
    @Argument(help: "path of the image")
    var imagePath: String
    
    @Flag(help: "output as json")
    var jsonify: Bool = false
    
    func run() throws {
        let exifImage = SwiftExif.Image(imagePath: URL(fileURLWithPath: imagePath))
        let exifDict = exifImage.Iptc()
        guard exifDict.count > 0 else {
            throw ExitCode.failure
        }
        if !jsonify {
            dump(exifDict)
        } else {
            print(
                String(
                    data: try JSONSerialization.data(withJSONObject: exifDict, options: [.sortedKeys, .prettyPrinted]),
                    encoding: .utf8
                ) ?? ""
            )
        }
    }
}

enum ExportError: CustomNSError, LocalizedError {
    case cannotDeserializeContent
    
    var errorCode: Int {
        switch self {
            case .cannotDeserializeContent:
                return 307
        }
    }
    
    var failureReason: String? {
        switch self {
            case .cannotDeserializeContent:
                return "Cannot deserialize content."
        }
    }
}

struct PiexlExportCommand: JsonifyCommand {
    static var configuration = CommandConfiguration(
        commandName: "export",
        abstract: "decode and print pixel objects in user comment field"
    )
    
    @Argument(help: "path of the image")
    var imagePath: String
    
    @Flag(help: "output as json")
    var jsonify: Bool = false
    
    func run() throws {
        let exifImage = SwiftExif.Image(imagePath: URL(fileURLWithPath: imagePath))
        let exifDict = exifImage.Exif()
        guard exifDict.count > 0 else {
            throw ExitCode.failure
        }
        guard let exifDict = exifDict["EXIF"],
              let userComment = exifDict[kCGImagePropertyExifUserComment as String],
              let archivedContentData = Data(base64Encoded: userComment)
        else {
            throw ExitCode.failure
        }
        guard let archivedContent = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archivedContentData) as? Content else {
            throw ExportError.cannotDeserializeContent
        }
        if !jsonify {
            dump(archivedContent)
        } else {
            print(
                String(
                    data: try JSONSerialization.data(withJSONObject: exifDict, options: [.sortedKeys, .prettyPrinted]),
                    encoding: .utf8
                ) ?? ""
            )
        }
    }
}
