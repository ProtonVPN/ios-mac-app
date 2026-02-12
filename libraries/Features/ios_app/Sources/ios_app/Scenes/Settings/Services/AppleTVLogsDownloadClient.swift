//
//  Created on 12/02/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct AppleTVLogsDownloadClient {
    var download: @Sendable () async throws -> URL
    var cancel: @Sendable () -> Void
}

extension AppleTVLogsDownloadClient: DependencyKey {
    static let liveValue: AppleTVLogsDownloadClient = {
        let service = AppleTVLogsDownloadService()
        return AppleTVLogsDownloadClient(
            download: {
                try await withTaskCancellationHandler(operation: {
                    try await withCheckedThrowingContinuation { continuation in
                        service.downloadLogs { result in
                            continuation.resume(with: result)
                        }
                    }
                }, onCancel: {
                    service.cancel()
                })
            },
            cancel: {
                service.cancel()
            }
        )
    }()
}

extension DependencyValues {
    var appleTVLogsDownloadClient: AppleTVLogsDownloadClient {
        get { self[AppleTVLogsDownloadClient.self] }
        set { self[AppleTVLogsDownloadClient.self] = newValue }
    }
}
