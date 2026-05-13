//
//  Created on 03/06/2024.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import CoreConnection
import Dependencies
import DependenciesMacros
import Domain
import Foundation
import IPCErgonomics
import IssueReporting
import LocalAgentIPC

@DependencyClient
public struct LocalAgentClient {
    public internal(set) var settings: () throws -> IPCLASettingsPayload
    public internal(set) var settingsStream: () -> AsyncStream<IPCLASettingsPayload> = { .finished }
    public internal(set) var eventStream: () -> AsyncStream<LocalAgent.Event> = { .finished }
    public internal(set) var requestsStream: () -> AsyncStream<LocalAgent.Request> = { .finished }
    public internal(set) var postEventFromExtension: (_ event: LocalAgent.Event) throws -> Void
    public internal(set) var postRequestToExtension: (_ request: LocalAgent.Request) throws -> Void
    public internal(set) var listenToForkSelectorRequests: (_ callback: @escaping () -> Void) -> Void
    public internal(set) var writeSettings: (_ body: (inout IPCLASettingsPayload) -> Void) -> Void
}

extension LocalAgentClient: DependencyKey {
    public static let liveValue: LocalAgentClient = {
        let containerURL = try! FileManager.default.mainContainerURL

        let fromExtensionChannel = try! IPCNotifications.Channel<LocalAgent.Event>(
            notification: .localAgentFromExtensionEvents,
            fileURL: containerURL.appending(component: "la_from_ext_events")
        )
        let toExtensionChannel = try! IPCNotifications.Channel<LocalAgent.Request>(
            notification: .localAgentToExtensionRequests,
            fileURL: containerURL.appending(component: "la_to_ext_requests")
        )
        let settingsChannel = try! IPCNotifications.RawChannel<IPCLASettingsPayload>(
            notification: .localAgentSettings,
            fileURL: containerURL.appending(component: "la_settings")
        )

        return LocalAgentClient {
            try settingsChannel.read()
        } settingsStream: {
            settingsChannel.stream()
        } eventStream: {
            fromExtensionChannel.stream()
        } requestsStream: {
            toExtensionChannel.stream(includingCurrentValue: true)
        } postEventFromExtension: { event in
            try fromExtensionChannel.post(event)
        } postRequestToExtension: { request in
            try toExtensionChannel.post(request)
        } listenToForkSelectorRequests: { callback in
            IPCNotifications.observe(.extensionForkSelectorRequest, callback: callback)
        } writeSettings: { body in
            settingsChannel.mutate(body)
        }
    }()
}

public extension DependencyValues {
    var localAgent: LocalAgentClient {
        get { self[LocalAgentClient.self] }
        set { self[LocalAgentClient.self] = newValue }
    }
}
