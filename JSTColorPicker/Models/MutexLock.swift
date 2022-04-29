//
//  MutexLock.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/4/17.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

final class MutexLock {
    private var mutex: pthread_mutex_t = {
        var mutex = pthread_mutex_t()
        pthread_mutex_init(&mutex, nil)
        return mutex
    }()
    
    func tryLock() -> Bool {
        return pthread_mutex_trylock(&mutex) == 0
    }

    func lock() {
        pthread_mutex_lock(&mutex)
    }

    func unlock() {
        pthread_mutex_unlock(&mutex)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }
}
