//
//  AuxiliaryExecute+Promise.swift
//  JSTColorPicker
//
//  Created by Darwin on 2021/12/9.
//  Copyright © 2021 JST. All rights reserved.
//

import Foundation
import AuxiliaryExecute
import PromiseKit

extension AuxiliaryExecute {

    struct SpawnResult {
        let exitCode: Int
        let stdout: String
        let stderr: String
    }

    static func promiseSpawn
    (
        command: String,
        args: [String] = [],
        environment: [String: String] = [:],
        timeout: Double = 0
    ) -> Promise<SpawnResult>
    {
        return Promise<SpawnResult> { seal in
            let recipe = AuxiliaryExecute.spawn(
                command: command,
                args: args,
                environment: environment,
                timeout: timeout
            )
            if let error = recipe.error {
                seal.reject(error)
            } else {
                seal.fulfill(SpawnResult(exitCode: recipe.exitCode, stdout: recipe.stdout, stderr: recipe.stderr))
            }
        }
    }

    static func promiseBash(
        command: String,
        environment: [String: String] = [:],
        timeout: Double = 0
    ) -> Promise<SpawnResult>
    {
        let aux = AuxiliaryExecute.local
        return Promise<SpawnResult> { seal in
            let recipe = aux.bash(
                command: command,
                environment: environment,
                timeout: timeout
            )
            if let error = recipe.error {
                seal.reject(error)
            } else {
                seal.fulfill(SpawnResult(exitCode: recipe.exitCode, stdout: recipe.stdout, stderr: recipe.stderr))
            }
        }
    }

}
