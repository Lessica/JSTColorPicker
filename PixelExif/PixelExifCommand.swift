//
//  PixelExifCommand.swift
//  PixelExif
//
//  Created by Rachel on 2021/12/15.
//  Copyright © 2021 JST. All rights reserved.
//

import ArgumentParser

@main
struct PixelExifCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "pixelexif",
        abstract: "A wrapping executable for SwiftExif, which is a wrapping library for libexif and libiptcdata for Swift to provide a JPEG metadata extraction on Linux and macOS.",
        version: "2.10",
        subcommands: [
            PixelExifEnteries.self,
            PixelExifRawEnteries.self,
        ]
    )
}

struct PixelExifEnteries: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "enteries",
        abstract: "read and print exif dictionary of specific image in a human-readable format"
    )
    
    @Argument(help: "path of the image")
    var imageURL: String
    
    func run() throws {
        
    }
}

struct PixelExifRawEnteries: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "raw_enteries",
        abstract: "read and print exif dictionary of specific image in raw format"
    )
    
    @Argument(help: "path of the image")
    var imageURL: String
    
    func run() throws {
        
    }
}
