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
    
    private var completionHandlers = [Int: (URL?, URLResponse?, Error?) -> Void]()
    private var isCancelled: Bool = false
    
    internal func addCompletionHandler(forTask task: URLSessionDownloadTask, completion: @escaping (URL?, URLResponse?, Error?) -> Void) {
        self.lastDownloadTask = task
        completionHandlers[task.taskIdentifier] = completion
    }
    
    internal func removeCompletionHandler(forTask task: URLSessionDownloadTask) {
        completionHandlers.removeValue(forKey: task.taskIdentifier)
    }
    
    internal func removeAllCompletionHandlers() {
        completionHandlers.removeAll()
    }
    
    internal func cancel() {
        self.isCancelled = true
    }
    
    private func internalCancel() {
        self.lastDownloadTask?.cancel()
    }
    
    private(set) weak var lastDownloadTask: URLSessionDownloadTask?
    private(set) weak var lastSession: URLSession?
    
    @Published var currentError: Error?
    @Published var downloadState: (currentURL: URL, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)?
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        self.lastSession = session
        self.lastDownloadTask = downloadTask
        self.currentError = nil
        if let currentRequestURL = downloadTask.currentRequest?.url {
            self.downloadState = (currentRequestURL, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        } else {
            self.downloadState = nil
        }
        if isCancelled {
            internalCancel()
            return
        }
    }
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didResumeAtOffset fileOffset: Int64,
        expectedTotalBytes: Int64
    ) {
        self.lastSession = session
        self.lastDownloadTask = downloadTask
        self.currentError = nil
        if let currentRequestURL = downloadTask.currentRequest?.url {
            self.downloadState = (currentRequestURL, fileOffset, fileOffset, expectedTotalBytes)
        } else {
            self.downloadState = nil
        }
        if isCancelled {
            internalCancel()
            return
        }
    }
    
    internal func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        self.lastSession = session
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
        self.lastSession = session
        self.lastDownloadTask = nil
        self.currentError = error
        self.downloadState = nil
        if task.response != nil || task.error != nil {
            self.completionHandlers[task.taskIdentifier]?(nil, task.response, task.error)
        }
        self.completionHandlers.removeValue(forKey: task.taskIdentifier)
    }
    
    internal func urlSession(
        _ session: URLSession,
        didBecomeInvalidWithError error: Error?
    ) {
        self.lastSession = session
        self.lastDownloadTask = nil
        if let error = error {
            self.completionHandlers.values.forEach { handler in
                handler(nil, nil, error)
            }
        }
        self.completionHandlers.removeAll()
    }
    
    deinit {
        debugPrint("\(className):\(#function)")
    }
}
