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

enum PixelMatchCommandLineError: LocalizedError {
    case fileDoesNotExist(url: URL)
    case sizesDoNotMatch(size1: CGSize, size2: CGSize)
    
    var failureReason: String? {
        switch self {
        case let .fileDoesNotExist(url):
            return String(format: NSLocalizedString("File does not exist: %@", comment: "PixelMatchCommandLineError"), url.path)
        case let .sizesDoNotMatch(size1, size2):
            return String(format: NSLocalizedString("Image sizes do not match: %dx%d vs %dx%d", comment: "PixelMatchCommandLineError"), size1.width, size1.height, size2.width, size2.height)
        }
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

let startTime = CFAbsoluteTimeGetCurrent()
guard let nsimg1 = NSImage(contentsOf: img1Path) else { throw PixelMatchCommandLineError.fileDoesNotExist(url: img1Path) }
let img1 = JSTPixelImage(nsImage: nsimg1)
guard let nsimg2 = NSImage(contentsOf: img2Path) else { throw PixelMatchCommandLineError.fileDoesNotExist(url: img2Path) }
let img2 = JSTPixelImage(nsImage: nsimg2)

guard img2.size.width == img1.size.width && img2.size.height == img1.size.height else {
    throw PixelMatchCommandLineError.sizesDoNotMatch(size1: img1.size, size2: img2.size)
}

let totalColumns = Int(img1.size.width)
, totalRows = Int(img1.size.height)
, totalCount = totalColumns * totalRows


// MARK: - Concurrent Perform

var threadCount: Int = 32
let upperBound = Int(ceil(sqrt(Double(totalRows))))
for tCount in stride(from: upperBound, to: 1, by: -1) {
    if totalRows % tCount == 0 {
        threadCount = tCount
        break
    }
}
let partialRows = totalRows / threadCount
, partialCount = totalColumns * partialRows

var diffCount: Int = 0
var threadOutputs: [Int: [JST_COLOR]] = [:]
let threadQueue = DispatchQueue(label: "SyncQueue")

DispatchQueue.concurrentPerform(iterations: threadCount) { (idx) in
    
    let processCount = includeAA || threadCount == 1 ? partialCount : (idx == 0 || idx == threadCount - 1 ? partialCount + totalColumns * 2 : partialCount + totalColumns * 4)
    let processRows  = includeAA || threadCount == 1 ? partialRows  : (idx == 0 || idx == threadCount - 1 ? partialRows  + 2                : partialRows  + 4)
    let rowOffset    = includeAA || idx == 0         ? 0            : totalColumns * 2
    
    let beginOffset  = idx * partialCount - rowOffset
    let endOffset    = beginOffset + processCount
    if includeAA {
        debugPrint("thread#\(idx): process[\(beginOffset)..<\(endOffset)](\(processCount))")
    }
    else {
        let validBegin   = beginOffset + rowOffset
        let validEnd     = validBegin  + partialCount
        debugPrint("thread#\(idx): process[\(beginOffset)..<\(endOffset)](\(processCount))->valid[\(validBegin)..<\(validEnd)](\(partialCount))")
    }
    
    var threadOutputs0 = [JST_COLOR](
        repeating: JST_COLOR(the_color: 0),
        count: processCount
    )
    var a32 = Array(UnsafeBufferPointer(
        start: img1.internalPointer.pointee.pixels + beginOffset,
        count: processCount
    ))
    var b32 = Array(UnsafeBufferPointer(
        start: img2.internalPointer.pointee.pixels + beginOffset,
        count: processCount
    ))
    
    let diffCount0 = try! PixelMatch(
        a32: &a32,
        b32: &b32,
        output: &threadOutputs0,
        width: totalColumns,
        height: processRows,
        options: options
    )
    
    threadQueue.sync {
        threadOutputs[idx] = Array(threadOutputs0[rowOffset..<rowOffset + partialCount])
        diffCount += diffCount0
    }
    
}

var outputs: [JST_COLOR] = []
for idx in 0..<threadCount {
    outputs += threadOutputs[idx]!
}
assert(outputs.count == totalCount)


// MARK: - Output Differences

let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print(String(format: "time elapsed: %.3fs", timeElapsed))
print(String(format: "approximate count: \(diffCount), difference: %.3f%%", Double(diffCount) / Double(totalCount) * 100.0))
if diffCount > 0 {
    let img = UnsafeMutablePointer<JST_IMAGE>.allocate(capacity: MemoryLayout<JST_IMAGE>.size)
    img.pointee.orientation = 0
    img.pointee.is_destroyed = 1
    img.pointee.width = Int32(totalColumns)
    img.pointee.height = Int32(totalRows)
    img.pointee.pixels = UnsafeMutablePointer(mutating: outputs)
    try JSTPixelImage(internalPointer: img).pngRepresentation().write(to: diffPath)
}
