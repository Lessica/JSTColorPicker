//
//  main.swift
//  PixelMatch
//
//  Created by Darwin on 3/12/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Foundation

public extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("Usage: pixelmatch image1.png image2.png diff.png [threshold=0.005] [includeAA=false]")
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

let img1 = JSTPixelImage(nsImage: NSImage(contentsOf: img1Path)!)
let img2 = JSTPixelImage(nsImage: NSImage(contentsOf: img2Path)!)

guard img2.size.width == img1.size.width && img2.size.height == img1.size.height else {
    print("Image dimensions do not match: \(img1.size.width)x\(img1.size.height) vs \(img2.size.width)x\(img2.size.height)")
    exit(EXIT_FAILURE)
}

let totalWidth = Int(img1.size.width)
, totalHeight = Int(img1.size.height)
, totalCount = totalWidth * totalHeight
var threadCount: Int = 1
for tCount in stride(from: 32, to: 1, by: -1) {
    if totalHeight % tCount == 0 {
        threadCount = tCount
        break
    }
}

let partialHeight = Int(img1.size.height / CGFloat(threadCount))
, partialCount = totalWidth * partialHeight

var diffCount: Int = 0
var threadOutputs: [Int: [JST_COLOR]] = [:]

var offset = 0
let syncQueue = DispatchQueue(label: "SyncQueue")
DispatchQueue.concurrentPerform(iterations: threadCount) { (idx) in
    var threadOutputs0 = [JST_COLOR](repeating: JST_COLOR(the_color: 0), count: partialCount)
    var a32 = Array(UnsafeBufferPointer(start: img1.internalPointer.pointee.pixels + idx * partialCount, count: partialCount))
    var b32 = Array(UnsafeBufferPointer(start: img2.internalPointer.pointee.pixels + idx * partialCount, count: partialCount))
    let diffCount0 = try! PixelMatch(
        a32: &a32,
        b32: &b32,
        output: &threadOutputs0,
        width: totalWidth,
        height: partialHeight,
        options: options
    )
    syncQueue.sync {
        threadOutputs[idx] = threadOutputs0
        diffCount += diffCount0
    }
}

var outputs: [JST_COLOR] = []
for idx in 0..<threadCount {
    outputs += threadOutputs[idx]!
}

print("different pixels: \(diffCount)")
print(String(format: "error: %.2f%%", Double(diffCount) / Double(totalCount)))

if diffCount > 0 {
    let img = UnsafeMutablePointer<JST_IMAGE>.allocate(capacity: MemoryLayout<JST_IMAGE>.size)
    img.pointee.orientation = 0
    img.pointee.is_destroyed = 1
    img.pointee.width = Int32(totalWidth)
    img.pointee.height = Int32(totalHeight)
    img.pointee.pixels = UnsafeMutablePointer(mutating: outputs)
    try JSTPixelImage(internalPointer: img).pngRepresentation().write(to: diffPath)
}
