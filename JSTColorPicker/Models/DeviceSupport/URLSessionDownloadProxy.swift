//
//  URLSessionDownloadProxy.swift
//  JSTColorPicker
//
//  Created by Mason Rachel on 2022/4/15.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa
import Combine

final class URLSessionDownloadProxy: NSObject, URLSessionDownloadDelegate {
    
    var completionHandlers = [Int: (URL?, URLResponse?, Error?) -> Void]()
    weak var lastDownloadTask: URLSessionDownloadTask?
    
    @Published var currentError: Error?
    @Published var downloadState: (currentURL: URL, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)?
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        self.lastDownloadTask = downloadTask
        self.currentError = nil
        if let currentRequestURL = downloadTask.currentRequest?.url {
            self.downloadState = (currentRequestURL, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        } else {
            self.downloadState = nil
        }
    }
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        self.lastDownloadTask = downloadTask
        self.currentError = nil
        if let currentRequestURL = downloadTask.currentRequest?.url {
            self.downloadState = (currentRequestURL, fileOffset, fileOffset, expectedTotalBytes)
        } else {
            self.downloadState = nil
        }
    }
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        self.lastDownloadTask = downloadTask
        self.currentError = nil
        self.downloadState = nil
        self.completionHandlers[downloadTask.taskIdentifier]?(location, downloadTask.response, downloadTask.error)
        self.completionHandlers.removeValue(forKey: downloadTask.taskIdentifier)
    }
    
    internal func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        self.lastDownloadTask = nil
        self.currentError = error
        self.downloadState = nil
        if task.response != nil || task.error != nil {
            self.completionHandlers[task.taskIdentifier]?(nil, task.response, task.error)
        }
        self.completionHandlers.removeValue(forKey: task.taskIdentifier)
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
}
