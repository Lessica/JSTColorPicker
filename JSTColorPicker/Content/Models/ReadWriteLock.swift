//
//  ReadWriteLock.swift
//  JSTColorPicker
//
//  Created by Rachel on 2021/4/17.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

final class ReadWriteLock {
    private var rwlock: pthread_rwlock_t = {
        var rwlock = pthread_rwlock_t()
        pthread_rwlock_init(&rwlock, nil)
        return rwlock
    }()

    func writeLock() {
        pthread_rwlock_wrlock(&rwlock)
    }

    func readLock() {
        pthread_rwlock_rdlock(&rwlock)
    }
    
    func tryReadLock() -> Bool {
        return pthread_rwlock_tryrdlock(&rwlock) == 0
    }
    
    func tryWriteLock() -> Bool {
        return pthread_rwlock_trywrlock(&rwlock) == 0
    }

    func unlock() {
        pthread_rwlock_unlock(&rwlock)
    }

    deinit {
        pthread_rwlock_destroy(&rwlock)
    }
}
