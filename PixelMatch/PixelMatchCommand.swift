//
//  PixelMatchCommand.swift
//  PixelMatch
//
//  Created by Darwin on 3/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import ArgumentParser


@main
struct PixelMatchCommand: ParsableCommand {

    static let service = PixelMatchService()

    static var configuration = CommandConfiguration(
        commandName: "pixelmatch",
        abstract: "Compute difference between two images with the same dimension pixel by pixel.",
        version: "2.10"
    )

    @Argument(help: ArgumentHelp("path of the first image to compute difference", valueName: "path-of-image-1"))
    var pathOfImage1: String

    @Argument(help: ArgumentHelp("path of the second image to compute difference", valueName: "path-of-image-2"))
    var pathOfImage2: String

    @Argument(help: ArgumentHelp("path of the output image", valueName: "output"))
    var pathOfOutputImage: String

    @Option(help: "matching threshold (0 to 1); smaller is more sensitive")
    var threshold: Double = 0.00

    @Option(help: "opacity of original image in diff ouput")
    var alpha: Double = 0.5

    @Flag(name: .customLong("skip-aa"), help: ArgumentHelp("whether to skip anti-aliasing detection", valueName: "skip-aa"))
    var skipAntiAliasing: Bool = false

    @Option(name: .customLong("aa-color"), help: ArgumentHelp("HEX color of anti-aliased pixels in diff output", valueName: "aa-color"))
    var antiAliasingColorHex: String = "#ffff00"

    @Flag(help: "draw the diff over a transparent background (a mask)")
    var diffMask: Bool = false

    @Option(name: .customLong("diff-color"), help: ArgumentHelp("HEX color of different pixels in diff output", valueName: "diff-color"))
    var diffColorHex: String = "#ff0000"

    @Option(name: [.customShort("j"), .long], help: "maximum concurrent jobs count")
    var maximumThreadCount: Int = ProcessInfo.processInfo.activeProcessorCount

    @Flag(name: .shortAndLong, help: "enable verbose logging")
    var verbose: Bool = false

    func run() throws {
        do {
            let img1URL = URL(fileURLWithPath: pathOfImage1).standardizedFileURL
            let img2URL = URL(fileURLWithPath: pathOfImage2).standardizedFileURL
            let outputURL = URL(fileURLWithPath: pathOfOutputImage)

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
                diffMask: diffMask,
                maximumThreadCount: maximumThreadCount,
                verbose: verbose
            )

            let img1Data = try Data(contentsOf: img1URL)
            guard let nsimg1 = NSImage(data: img1Data) else {
                throw PixelMatchService.Error.cannotLoadImage(url: img1URL)
            }
            let img1 = JSTPixelImage(systemImage: nsimg1)

            let img2Data = try Data(contentsOf: img2URL)
            guard let nsimg2 = NSImage(data: img2Data) else {
                throw PixelMatchService.Error.cannotLoadImage(url: img2URL)
            }
            let img2 = JSTPixelImage(systemImage: nsimg2)

            let output = try PixelMatchCommand.service.performConcurrentPixelMatch(img1, img2, options: opts)
            try output
                .pngRepresentation()
                .write(to: outputURL)
        } catch {
            var outputStream = StandardErrorOutputStream()
            print(error.localizedDescription, to: &outputStream)
            throw error
        }
    }
}
