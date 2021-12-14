//
//  main.swift
//  PixelMatch
//
//  Created by Darwin on 3/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import ArgumentParser


@main
struct PixelMatchCommand: ParsableCommand {

    static let service = PixelMatchService()

    @Argument(help: ArgumentHelp(valueName: "path-of-image-1"))
    var pathOfImage1: String

    @Argument(help: ArgumentHelp(valueName: "path-of-image-2"))
    var pathOfImage2: String

    @Argument(help: ArgumentHelp(valueName: "output"))
    var pathOfOutputImage: String

    @Option(help: "matching threshold (0 to 1); smaller is more sensitive")
    var threshold: Double = 0.005

    @Flag(help: ArgumentHelp("whether to skip anti-aliasing detection", valueName: "skip-aa"))
    var skipAntiAliasing: Bool = false

    @Option(help: "opacity of original image in diff ouput")
    var alpha: Double = 0.5

    @Option(help: ArgumentHelp("HEX color of anti-aliased pixels in diff output", valueName: "aa-color"))
    var antiAliasingColorHex: String = "#ffff00"

    @Option(help: ArgumentHelp("HEX color of different pixels in diff output", valueName: "diff-color"))
    var diffColorHex: String = "#ff0000"

    @Option(help: "draw the diff over a transparent background (a mask)")
    var diffMask: Bool = false

    mutating func run() throws {
        let img1Path = URL(fileURLWithPath: pathOfImage1).standardizedFileURL
        let img2Path = URL(fileURLWithPath: pathOfImage2).standardizedFileURL
        let diffPath = URL(fileURLWithPath: pathOfOutputImage)

        let antiAliasingColor = NSColor(hex: antiAliasingColorHex)
        let diffColor = NSColor(hex: diffColorHex)
        let opts = MatchOptions(
            threshold: threshold,
            includeAA: !skipAntiAliasing,
            alpha: alpha,
            aaColor: (
                UInt8(antiAliasingColor.redComponent * 255.0),
                UInt8(antiAliasingColor.greenComponent * 255.0),
                UInt8(antiAliasingColor.blueComponent * 255.0)
            ),
            diffColor: (
                UInt8(diffColor.redComponent * 255.0),
                UInt8(diffColor.greenComponent * 255.0),
                UInt8(diffColor.blueComponent * 255.0)
            ),
            diffMask: diffMask
        )

        guard let nsimg1 = NSImage(contentsOf: img1Path) else {
            // TODO: error type
            throw PixelMatchService.Error.fileDoesNotExist(url: img1Path)
        }
        let img1 = JSTPixelImage(nsImage: nsimg1)
        
        guard let nsimg2 = NSImage(contentsOf: img2Path) else {
            throw PixelMatchService.Error.fileDoesNotExist(url: img2Path)
        }
        let img2 = JSTPixelImage(nsImage: nsimg2)

        let output = try PixelMatchCommand.service.performConcurrentPixelMatch(img1, img2, options: opts)
        try output
            .pngRepresentation()
            .write(to: diffPath)

    }
}
