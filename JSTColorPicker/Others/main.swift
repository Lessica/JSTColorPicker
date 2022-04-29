//
//  main.swift
//  JSTColorPicker
//
//  Created by Darwin on 4/23/21.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation

#if !DEBUG
do {
    typealias ptrace = @convention(c) (_ request: Int, _ pid: Int, _ addr: Int, _ data: Int) -> AnyObject
    let open = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_NOW)
    if unsafeBitCast(open, to: Int.self) > 0x1024 {
        let result = dlsym(open, "ptrace")
        if let result = result {
            let target = unsafeBitCast(result, to: ptrace.self)
            let _ = target(0x1F, 0, 0, 0)
        }
    }
}
#endif

exit(NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv))
