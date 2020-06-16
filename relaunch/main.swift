//
//  main.swift
//  relaunch
//
//  Created by Darwin on 6/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

import Cocoa

// KVO helper
class Observer: NSObject {
    
    let _callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        _callback = callback
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
    {
        _callback()
    }
    
}


// main
autoreleasepool {
    
    // the application pid
    guard let parentPID = Int32(CommandLine.arguments[1]) else {
        fatalError("Relaunch: parentPID == nil.")
    }
    
    // get the application instance
    if let app = NSRunningApplication(processIdentifier: parentPID) {
        
        // application URL
        let bundleURL = app.bundleURL!
        
        // terminate() and wait terminated.
        let listener = Observer { CFRunLoopStop(CFRunLoopGetCurrent()) }
        app.addObserver(listener, forKeyPath: "isTerminated", context: nil)
        app.terminate()
        CFRunLoopRun() // wait KVO notification
        app.removeObserver(listener, forKeyPath: "isTerminated", context: nil)
        
        // relaunch
        do {
            try NSWorkspace.shared.launchApplication(at: bundleURL, configuration: [:])
        } catch {
            fatalError("Relaunch: NSWorkspace.shared().launchApplication failed.")
        }
    }
    
}
