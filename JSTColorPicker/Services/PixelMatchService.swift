//
//  PixelMatchService.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

final class PixelMatchService {
    
    enum Error: LocalizedError {
        
        case taskConflict
        case cannotLoadImage(url: URL)
        case sizesDoNotMatch(size1: CGSize, size2: CGSize)
        case noDifferenceDetected
        
        var failureReason: String? {
            switch self {
            case .taskConflict:
                return NSLocalizedString("Another task is in process, abort.", comment: "PixelMatchServiceError")
            case let .cannotLoadImage(url):
                return String(format: NSLocalizedString("Cannot load image: %@.", comment: "PixelMatchServiceError"), url.path)
            case let .sizesDoNotMatch(size1, size2):
                return String(format: NSLocalizedString("Image sizes do not match: %dx%d vs %dx%d", comment: "PixelMatchServiceError"), Int(size1.width), Int(size1.height), Int(size2.width), Int(size2.height))
            case .noDifferenceDetected:
                return NSLocalizedString("No difference detected. Decrease the \"Match Threshold\" in \"Preferences -> General -> Compare\" and try again.", comment: "PixelMatchServiceError")
            }
        }
        
    }
    
    public private(set) var isProcessing: Bool = false
    
#if WITH_COCOA
    public func performConcurrentPixelMatch(_ img1: JSTPixelImage, _ img2: JSTPixelImage) throws -> JSTPixelImage {
        var options = MatchOptions()
        options.threshold = UserDefaults.standard[.pixelMatchThreshold]
        options.includeAA = UserDefaults.standard[.pixelMatchIncludeAA]
        options.alpha = UserDefaults.standard[.pixelMatchAlpha]
        if let aaColor: NSColor = (UserDefaults.standard[.pixelMatchAAColor] ?? NSColor.systemYellow).usingColorSpace(.deviceRGB) {
            options.aaColor = (UInt8(aaColor.redComponent * 255.0), UInt8(aaColor.greenComponent * 255.0), UInt8(aaColor.blueComponent * 255.0))
        }
        if let diffColor: NSColor = (UserDefaults.standard[.pixelMatchDiffColor] ?? NSColor.systemRed).usingColorSpace(.deviceRGB) {
            options.diffColor = (UInt8(diffColor.redComponent * 255.0), UInt8(diffColor.greenComponent * 255.0), UInt8(diffColor.blueComponent * 255.0))
        }
        options.diffMask = UserDefaults.standard[.pixelMatchDiffMask]
        return try performConcurrentPixelMatch(img1, img2, options: options)
    }
#endif
    
    public func performConcurrentPixelMatch(_ img1: JSTPixelImage, _ img2: JSTPixelImage, options: MatchOptions) throws -> JSTPixelImage {
        guard !isProcessing else { throw PixelMatchService.Error.taskConflict }
        isProcessing = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        guard img2.size.width == img1.size.width && img2.size.height == img1.size.height else {
            isProcessing = false
            throw PixelMatchService.Error.sizesDoNotMatch(size1: img1.size, size2: img2.size)
        }

        let totalColumns = Int(img1.size.width)
        , totalRows = Int(img1.size.height)
        , totalCount = totalColumns * totalRows
        var outputStream = StandardErrorOutputStream()


        // MARK: - Concurrent Perform

        var threadCount: Int = 32
        let upperBound = min(Int(ceil(sqrt(Double(totalRows)))), max(options.maximumThreadCount, 1))
        for tCount in stride(from: upperBound, to: 1, by: -1) {
            if totalRows % tCount == 0 {
                threadCount = tCount
                break
            }
        }
        if options.verbose {
            print("thread count: \(threadCount)", to: &outputStream)
        }

        let partialRows = totalRows / threadCount
        , partialCount = totalColumns * partialRows

        var diffCount: Int = 0
        var threadOutputs: [Int: [JST_COLOR]] = [:]
        let threadQueue = DispatchQueue(label: "SyncQueue")

        DispatchQueue.concurrentPerform(iterations: threadCount) { (idx) in
            
            let processCount = options.includeAA || threadCount == 1 ? partialCount : (idx == 0 || idx == threadCount - 1 ? partialCount + totalColumns * 2 : partialCount + totalColumns * 4)
            let processRows  = options.includeAA || threadCount == 1 ? partialRows  : (idx == 0 || idx == threadCount - 1 ? partialRows  + 2                : partialRows  + 4)
            let rowOffset    = options.includeAA || idx == 0         ? 0            : totalColumns * 2
            
            let beginOffset  = idx * partialCount - rowOffset
            let endOffset    = beginOffset + processCount
            if options.verbose {
                if options.includeAA {
                    threadQueue.sync {
                        print("thread#\(idx): process[\(beginOffset)..<\(endOffset)](\(processCount))", to: &outputStream)
                    }
                }
                else {
                    let validBegin   = beginOffset + rowOffset
                    let validEnd     = validBegin  + partialCount
                    threadQueue.sync {
                        print("thread#\(idx): process[\(beginOffset)..<\(endOffset)](\(processCount))->valid[\(validBegin)..<\(validEnd)](\(partialCount))", to: &outputStream)
                    }
                }
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
        let outputsPointer = UnsafeMutableBufferPointer<JST_COLOR>.allocate(capacity: totalCount)
        _ = outputsPointer.initialize(from: outputs)
        

        // MARK: - Output Differences

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print(String(format: "time elapsed: %.3fs", timeElapsed), to: &outputStream)
        print(String(format: "approximate count: \(diffCount), difference: %.3f%%", Double(diffCount) / Double(totalCount) * 100.0), to: &outputStream)
        guard diffCount > 0 else {
            isProcessing = false
            throw PixelMatchService.Error.noDifferenceDetected
        }
        
        let img = UnsafeMutablePointer<JST_IMAGE>.allocate(capacity: 1)
        img.pointee.orientation = 0
        img.pointee.is_destroyed = 0
        img.pointee.width = Int32(totalColumns)
        img.pointee.height = Int32(totalRows)
        img.pointee.pixels = outputsPointer.baseAddress
        isProcessing = false
        return JSTPixelImage(internalPointer: img)
    }
    
}
