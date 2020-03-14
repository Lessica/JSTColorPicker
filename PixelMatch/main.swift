//
//  main.swift
//  PixelMatch
//
//  Created by Darwin on 3/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

private extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: pixelmatch image1.png image2.png diff.png [threshold=0.005] [includeAA=false]")
    exit(EXIT_FAILURE)
}

let img1Path = URL(fileURLWithPath: (args[safe: 1] ?? ""), relativeTo: nil)
, img2Path = URL(fileURLWithPath: (args[safe: 2] ?? ""), relativeTo: nil)
, diffPath = URL(fileURLWithPath: (args[safe: 3] ?? ""), relativeTo: nil)
, threshold = Double(args[safe: 4] ?? "")
, includeAA = args[safe: 5] == "true"

var options = MatchOptions()
if threshold != nil { options.threshold = CGFloat(threshold!) }
options.includeAA = includeAA
dump(options)


// MARK: - Process Begin


guard let nsimg1 = NSImage(contentsOf: img1Path) else { throw PixelMatchServiceError.fileDoesNotExist(url: img1Path) }
let img1 = JSTPixelImage(nsImage: nsimg1)
guard let nsimg2 = NSImage(contentsOf: img2Path) else { throw PixelMatchServiceError.fileDoesNotExist(url: img2Path) }
let img2 = JSTPixelImage(nsImage: nsimg2)

let output = try PixelMatchService().performConcurrentPixelMatch(img1, img2, options: options)
try output.pngRepresentation().write(to: diffPath)

