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
    public internal(set) var listenToForkSelectorRequests: (_ callback: @escaping () -> Void) -> Void

    public internal(set) var connectionData: () throws -> IPCConnectionDataPayload
    public internal(set) var connectionDataStream: () -> AsyncStream<IPCConnectionDataPayload> = { .finished }
    public internal(set) var writeConnectionData: (_ body: (inout IPCConnectionDataPayload) -> Void) -> Void

    public internal(set) var trafficStats: () throws -> IPCStatsPayload
    public internal(set) var trafficStatsStream: () -> AsyncStream<IPCStatsPayload> = { .finished }
    public internal(set) var writeTrafficStats: (_ body: (inout IPCStatsPayload) -> Void) -> Void

    public internal(set) var connectionStats: () throws -> IPCConnectionStatsPayload
    public internal(set) var connectionStatsStream: () -> AsyncStream<IPCConnectionStatsPayload> = { .finished }
    public internal(set) var writeConnectionStats: (_ body: (inout IPCConnectionStatsPayload) -> Void) -> Void

    public internal(set) var lastError: () throws -> IPCErrorPayload
    public internal(set) var errorStream: () -> AsyncStream<IPCErrorPayload> = { .finished }
    public internal(set) var reportError: (_ error: any Error) -> Void

    public internal(set) var appliedFeatures: () throws -> IPCAgentFeaturesPayload
    public internal(set) var appliedFeaturesStream: () -> AsyncStream<IPCAgentFeaturesPayload> = { .finished }
    public internal(set) var writeAppliedFeatures: (_ body: (inout IPCAgentFeaturesPayload) -> Void) -> Void

    /// Clears all shared memory regions.
    public internal(set) var zeroTunnelData: () -> Void
}

extension LocalAgentClient: DependencyKey {
    public static let liveValue: LocalAgentClient = {
        let containerURL = try! FileManager.default.mainContainerURL

        let connectionDataChannel = try! IPCNotifications.RawChannel<IPCConnectionDataPayload>(
            notification: .connectionData,
            fileURL: containerURL.appending(component: "connection_data")
        )
        let trafficStatsChannel = try! IPCNotifications.RawChannel<IPCStatsPayload>(
            notification: .localAgentStats,
            fileURL: containerURL.appending(component: "la_stats")
        )
        let connectionStatsChannel = try! IPCNotifications.RawChannel<IPCConnectionStatsPayload>(
            notification: .localAgentConnectionStats,
            fileURL: containerURL.appending(component: "la_connection_stats")
        )
        let errorChannel = try! IPCNotifications.RawChannel<IPCErrorPayload>(
            notification: .localAgentError,
            fileURL: containerURL.appending(component: "la_error")
        )
        let appliedFeaturesChannel = try! IPCNotifications.RawChannel<IPCAgentFeaturesPayload>(
            notification: .localAgentFeatures,
            fileURL: containerURL.appending(component: "la_features")
        )

        return LocalAgentClient { callback in
            IPCNotifications.observe(.extensionForkSelectorRequest, callback: callback)
        } connectionData: {
            try connectionDataChannel.read()
        } connectionDataStream: {
            connectionDataChannel.stream()
        } writeConnectionData: { body in
            connectionDataChannel.mutate(body)
        } trafficStats: {
            try trafficStatsChannel.read()
        } trafficStatsStream: {
            trafficStatsChannel.stream()
        } writeTrafficStats: { body in
            trafficStatsChannel.mutate(body)
        } connectionStats: {
            try connectionStatsChannel.read()
        } connectionStatsStream: {
            connectionStatsChannel.stream()
        } writeConnectionStats: { body in
            connectionStatsChannel.mutate(body)
        } lastError: {
            try errorChannel.read()
        } errorStream: {
            errorChannel.stream()
        } reportError: { error in
            errorChannel.mutate { $0 = IPCErrorPayload(error) }
        } appliedFeatures: {
            try appliedFeaturesChannel.read()
        } appliedFeaturesStream: {
            appliedFeaturesChannel.stream()
        } writeAppliedFeatures: { body in
            appliedFeaturesChannel.mutate(body)
        } zeroTunnelData: {
            connectionDataChannel.zero()
            trafficStatsChannel.zero()
            connectionStatsChannel.zero()
            errorChannel.zero()
            appliedFeaturesChannel.zero()
        }
    }()
}

public extension DependencyValues {
    var localAgent: LocalAgentClient {
        get { self[LocalAgentClient.self] }
        set { self[LocalAgentClient.self] = newValue }
    }
}
