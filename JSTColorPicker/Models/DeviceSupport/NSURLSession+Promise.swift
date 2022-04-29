//
//  NSURLSession+Promise.swift
//  JSTColorPicker
//
//  Created by Darwin on 2022/4/16.
//  Copyright © 2022 JST. All rights reserved.
//

import Cocoa
import PromiseKit

extension URLSession {
    
    func downloadProxyTask(_: PMKNamespacer, from url: URL, to saveLocation: URL, proxy: URLSessionDownloadProxy) -> Promise<(saveLocation: URL, response: URLResponse)> {
        return Promise { seal in
            let task = downloadTask(with: url)
            proxy.addCompletionHandler(forTask: task, completion: { tmp, rsp, err in
                if let error = err {
                    seal.reject(error)
                } else if let rsp = rsp, let tmp = tmp {
                    do {
                        try FileManager.default.moveItem(at: tmp, to: saveLocation)
                        seal.fulfill((saveLocation, rsp))
                    } catch {
                        seal.reject(error)
                    }
                } else {
                    seal.reject(PMKError.invalidCallingConvention)
                }
            })
            task.resume()
        }
    }
}
