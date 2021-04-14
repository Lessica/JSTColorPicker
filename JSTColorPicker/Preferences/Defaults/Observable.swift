//
//  Observable.swift
//  JSTColorPicker
//
//  Created by Rachel on 4/14/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

protocol Observable {
    var isSuspended: Bool { get set }
    func dispose()
}

extension Array where Element == Observable {

    func suspend() {
        forEach {
            var observer = $0
            observer.isSuspended = true
        }
    }

    func resume() {
        forEach {
            var observer = $0
            observer.isSuspended = false
        }
    }
}
