//
//  Created on 20/04/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
@testable import IPCErgonomics
import Testing

struct IPCHelperContext {
    enum Error: Swift.Error {
        case noContextProvided
        case noNotificationProvided
    }

    let mmapFileURL: URL
    let notification: IPCNotifications.Notification?

    static func url() throws(Error) -> URL {
        guard let context = current else { throw .noContextProvided }
        return context.mmapFileURL
    }

    static func sharedBuffer() throws -> IPCNotifications.SharedBuffer {
        guard let context = current else { throw Error.noContextProvided }
        return try IPCNotifications.SharedBuffer(url: context.mmapFileURL)
    }

    static func channel<T>(ofType _: T.Type) throws -> IPCNotifications.Channel<T> {
        guard let context = current else { throw Error.noContextProvided }
        guard let notification = context.notification else { throw Error.noNotificationProvided }
        return try IPCNotifications.Channel<T>(notification: notification, fileURL: context.mmapFileURL)
    }

    static func rawChannel<T>(ofType _: T.Type) throws -> IPCNotifications.RawChannel<T> {
        guard let context = current else { throw Error.noContextProvided }
        guard let notification = context.notification else { throw Error.noNotificationProvided }
        return try IPCNotifications.RawChannel<T>(notification: notification, fileURL: context.mmapFileURL)
    }

    @TaskLocal fileprivate static var current: IPCHelperContext?
}

struct IPCHelperContextTrait: TestTrait, TestScoping {
    let context: IPCHelperContext
    let cleanUp: Bool

    func provideScope(
        for _: Test,
        testCase _: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        try await IPCHelperContext.$current.withValue(context) {
            try await function()
            if cleanUp {
                try FileManager.default.removeItem(at: context.mmapFileURL)
            }
        }
    }
}

extension Trait where Self == IPCHelperContextTrait {
    static func ipcContext(
        mmapFileURL: URL,
        notification: IPCNotifications.Notification? = nil,
        cleanUp: Bool = true
    ) -> Self {
        let context = IPCHelperContext(mmapFileURL: mmapFileURL, notification: notification)
        return IPCHelperContextTrait(context: context, cleanUp: cleanUp)
    }
}
