//
//  Created on 2026-06-03 by Pawel Jurczyk.
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

import Dependencies
import DependenciesMacros
import Domain
import Foundation

@DependencyClient
public struct PCAPIndirectSharedPropertyUpdater: Sendable {
    /// Update the capture session shared property directly in the user defaults.
    /// We're guarding here against the app being killed while the pcap capture is terminated due to
    /// the connection being terminated.
    /// The way we update the shared property isn't great because we're not using the @Shared
    /// wrapper. When the wrapper decides to change the way it's persisted, this logic will be broken.
    /// We're doing it this way to avoid loading another dependency (swift-sharing) to the network extension.
    public var finishPCAPSession: @Sendable (_ reason: PacketCaptureInterruptionReason) -> Void
}

extension PCAPIndirectSharedPropertyUpdater: DependencyKey {
    public static var liveValue: PCAPIndirectSharedPropertyUpdater {
        PCAPIndirectSharedPropertyUpdater(
            finishPCAPSession: { reason in
                @Dependency(\.pcapFileManager) var pcapFileManager
                @Dependency(\.fileManagerClient) var fileManagerClient
                do {
                    guard let fileURL = pcapFileManager.retrieveLastPcapFileURL() else {
                        return
                    }
                    let fileSize = try fileManagerClient.fileSize(fileURL)
                    let endedSession = CaptureSession.sessionEnded(
                        urlWithSize: .init(url: fileURL, size: fileSize),
                        reason: reason
                    )
                    let encoded = try JSONEncoder().encode(endedSession)
                    UserDefaults.domainUserDefaults.setValue(encoded, forKey: CaptureSession.storageKey)
                } catch {
                    log.error("Failed to finish PCAP session", category: .app, metadata: ["error": "\(error)"])
                }
            }
        )
    }
}

public extension DependencyValues {
    var pcapSharedPropertyUpdater: PCAPIndirectSharedPropertyUpdater {
        get { self[PCAPIndirectSharedPropertyUpdater.self] }
        set { self[PCAPIndirectSharedPropertyUpdater.self] = newValue }
    }
}
