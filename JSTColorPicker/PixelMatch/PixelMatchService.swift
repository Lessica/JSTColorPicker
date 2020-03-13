//
//  PixelMatchService.swift
//  JSTColorPicker
//
//  Created by Darwin on 3/13/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

enum PixelMatchServiceError: LocalizedError {
    case taskConflict
    case fileDoesNotExist(url: URL)
    case sizesDoNotMatch(size1: CGSize, size2: CGSize)
    
    var failureReason: String? {
        switch self {
        case .taskConflict:
            return NSLocalizedString("Another task is in process, abort.", comment: "PixelMatchServiceError")
        case let .fileDoesNotExist(url):
            return String(format: NSLocalizedString("File does not exist: %@", comment: "PixelMatchServiceError"), url.path)
        case let .sizesDoNotMatch(size1, size2):
            return String(format: NSLocalizedString("Image sizes do not match: %dx%d vs %dx%d", comment: "PixelMatchServiceError"), size1.width, size1.height, size2.width, size2.height)
        }
    }
}

class PixelMatchService {
    
    public fileprivate(set) var isProcessing: Bool = false
    public var isInDifferenceMasking: Bool = false
    
    public func performConcurrentPixelMatch(_ img1: JSTPixelImage, _ img2: JSTPixelImage) throws -> JSTPixelImage? {
        var options = MatchOptions()
        options.threshold      = UserDefaults.standard[.pixelMatchThreshold]
        options.includeAA      = UserDefaults.standard[.pixelMatchIncludeAA]
        options.alpha          = UserDefaults.standard[.pixelMatchAlpha]
        let aaColor: NSColor   = UserDefaults.standard[.pixelMatchAAColor] ?? NSColor.systemYellow
        options.aaColor        = (UInt8(aaColor.redComponent * 255.0), UInt8(aaColor.greenComponent * 255.0), UInt8(aaColor.blueComponent * 255.0))
        let diffColor: NSColor = UserDefaults.standard[.pixelMatchDiffColor] ?? NSColor.systemRed
        options.diffColor      = (UInt8(diffColor.redComponent * 255.0), UInt8(diffColor.greenComponent * 255.0), UInt8(diffColor.blueComponent * 255.0))
        options.diffMask       = UserDefaults.standard[.pixelMatchDiffMask]
        return try performConcurrentPixelMatch(img1, img2, options: options)
    }
    
    public func performConcurrentPixelMatch(_ img1: JSTPixelImage, _ img2: JSTPixelImage, options: MatchOptions) throws -> JSTPixelImage? {
        guard !isProcessing else { throw PixelMatchServiceError.taskConflict }
        isProcessing = true
        
        let startTime = CFAbsoluteTimeGetCurrent()
        guard img2.size.width == img1.size.width && img2.size.height == img1.size.height else {
            isProcessing = false
            throw PixelMatchServiceError.sizesDoNotMatch(size1: img1.size, size2: img2.size)
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
            
            let processCount = options.includeAA || threadCount == 1 ? partialCount : (idx == 0 || idx == threadCount - 1 ? partialCount + totalColumns * 2 : partialCount + totalColumns * 4)
            let processRows  = options.includeAA || threadCount == 1 ? partialRows  : (idx == 0 || idx == threadCount - 1 ? partialRows  + 2                : partialRows  + 4)
            let rowOffset    = options.includeAA || idx == 0         ? 0            : totalColumns * 2
            
            let beginOffset  = idx * partialCount - rowOffset
            let endOffset    = beginOffset + processCount
            if options.includeAA {
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
        
        let outputsPointer = UnsafeMutableBufferPointer<JST_COLOR>.allocate(capacity: totalCount)
        var outputs = Array(outputsPointer)
        for idx in 0..<threadCount {
            outputs += threadOutputs[idx]!
        }
        

        // MARK: - Output Differences

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        debugPrint(String(format: "time elapsed: %.3fs", timeElapsed))
        debugPrint(String(format: "approximate count: \(diffCount), difference: %.3f%%", Double(diffCount) / Double(totalCount) * 100.0))
        if diffCount > 0 {
            let img = UnsafeMutablePointer<JST_IMAGE>.allocate(capacity: 1)
            img.pointee.orientation = 0
            img.pointee.is_destroyed = 0
            img.pointee.width = Int32(totalColumns)
            img.pointee.height = Int32(totalRows)
            img.pointee.pixels = outputsPointer.baseAddress
            isProcessing = false
            return JSTPixelImage(internalPointer: img)
        }
        
        isProcessing = false
        return nil
    }
    
}