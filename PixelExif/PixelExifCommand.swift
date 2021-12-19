//
//  PixelExifCommand.swift
//  PixelExif
//
//  Created by Rachel on 2021/12/19.
//  Copyright © 2021 JST. All rights reserved.
//

import ArgumentParser


@main
struct PixelExifCommand: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "pixelexif",
        abstract: "A wrapping executable for CoreGraphic to provide a JPEG/PNG metadata extraction on macOS.",
        version: "2.10",
        subcommands: [
            PixelExifEnteriesCommand.self,
            PixelExifContentsCommand.self,
        ]
    )
}

struct PixelExifEnteriesCommand: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "enteries",
        abstract: "read and print exif dictionary of specific image in a human-readable format"
    )

    @Argument(help: "path of the image")
    var imagePath: String

    @Flag(help: "output as json")
    var jsonify: Bool = false

    func run() throws {
        do {
            let bridgedTypes = [
                Content.self,
                ContentItem.self,
                PixelColor.self,
                PixelArea.self,
                PixelImage.self,
                Screenshot.self,
            ] as [AnyClass]
            let writerModuleName = "JSTColorPicker"
            for bridgedType in bridgedTypes {
                let bridgedName = "\(writerModuleName).\(String(describing: bridgedType))"
                NSKeyedUnarchiver.setClass(bridgedType, forClassName: bridgedName)
            }
            if let metadata = try Screenshot(contentsOf: URL(fileURLWithPath: imagePath), ofType: "public.png").metadata {
                if !jsonify {
                    dump(metadata)
                } else {
                    let contentData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
                    print(String(data: contentData, encoding: .utf8)!)
                }
            }
        } catch {
            var outputStream = StandardErrorOutputStream()
            print(error.localizedDescription, to: &outputStream)
            throw error
        }
    }
}

struct PixelExifContentsCommand: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "contents",
        abstract: "parse JSTColorPicker metadata from exif dictionary of specific image in a human-readable format"
    )

    @Argument(help: "path of the image")
    var imagePath: String

    @Flag(help: "output as json")
    var jsonify: Bool = false

    func run() throws {
        do {
            let bridgedTypes = [
                Content.self,
                ContentItem.self,
                PixelColor.self,
                PixelArea.self,
                PixelImage.self,
                Screenshot.self,
            ] as [AnyClass]
            let writerModuleName = "JSTColorPicker"
            for bridgedType in bridgedTypes {
                let bridgedName = "\(writerModuleName).\(String(describing: bridgedType))"
                NSKeyedUnarchiver.setClass(bridgedType, forClassName: bridgedName)
            }
            if let content = try Screenshot(contentsOf: URL(fileURLWithPath: imagePath), ofType: "public.png").content {
                if !jsonify {
                    dump(content)
                } else {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    encoder.dataEncodingStrategy = .base64
                    encoder.dateEncodingStrategy = .secondsSince1970
                    encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
                    let contentData = try encoder.encode(content)
                    print(String(data: contentData, encoding: .utf8)!)
                }
            }
        } catch {
            var outputStream = StandardErrorOutputStream()
            print(error.localizedDescription, to: &outputStream)
            throw error
        }
    }
}
