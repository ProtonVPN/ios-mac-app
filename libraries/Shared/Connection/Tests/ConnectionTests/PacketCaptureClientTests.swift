//
//  Created on 11/08/2026.
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

#if DEBUG
    import ComposableArchitecture
    import ConcurrencyExtras
    @testable import Connection
    import CoreConnection
    import Domain
    import enum ExtensionIPC.ProviderMessageError
    import ExtensionSync
    import Foundation
    import IPCDefinitions
    import Testing
    import VPNAppCore

    @Suite("Packet capture client")
    struct PacketCaptureClientTests {
        private static let file = URL(filePath: "/tmp/PcapFiles/capture.pcap")
        private static let created = Date(timeIntervalSince1970: 1_754_000_000)

        private static func client(
            report: PacketCaptureReport,
            file: PCAPFileManager.CaptureFile?,
            removed: LockIsolated<Bool> = .init(false),
            sent: LockIsolated<[ProTUNMessage.Request.PcapRequest]> = .init([])
        ) -> PacketCaptureClient {
            withDependencies {
                $0.extensionIPC.currentPacketCapture = { report }
                $0.extensionIPC.observePacketCapture = { .finished }
                $0.pcapFileManager.captureFile = { file }
                $0.pcapFileManager.removeCaptureFiles = { removed.setValue(true) }
                $0.tunnelMessageSender = TunnelMessageSender { request in
                    if case let .pcapRequest(pcapRequest) = request.payload {
                        sent.withValue { $0.append(pcapRequest) }
                    }
                    return .init(payload: .ack)
                }
            } operation: {
                .liveValue
            }
        }

        @Test
        func noFileMeansNoSession() {
            let client = Self.client(report: .cleared, file: nil)
            #expect(client.session() == .noSession)
        }

        @Test
        func recordingReportMeansStartedSession() {
            let since = Date(timeIntervalSince1970: 1_755_000_000)
            let client = Self.client(
                report: .recording(since: since),
                file: .init(url: Self.file, size: 0, created: Self.created)
            )
            #expect(client.session() == .sessionStarted(urlWithDate: .init(url: Self.file, date: since)))
        }

        @Test
        func stoppedReportWithPacketsMeansEndedSession() {
            let client = Self.client(
                report: .stopped(.explicitStop),
                file: .init(url: Self.file, size: 123, created: Self.created)
            )
            #expect(client.session() == .sessionEnded(urlWithSize: .init(url: Self.file, size: 123)))
        }

        @Test
        func stoppedReportWithEmptyFileMeansPendingSession() {
            let client = Self.client(
                report: .cleared,
                file: .init(url: Self.file, size: 0, created: Self.created)
            )
            #expect(client.session() == .sessionPending(urlWithDate: .init(url: Self.file, date: Self.created)))
        }

        @Test
        func startingReportMeansPendingSessionEvenWithAGrowingFile() {
            let client = Self.client(
                report: .starting,
                file: .init(url: Self.file, size: 24, created: Self.created)
            )
            #expect(client.session() == .sessionPending(urlWithDate: .init(url: Self.file, date: Self.created)))
        }

        @Test
        func stoppingAPendingCaptureDeletesItsFile() async {
            let removed = LockIsolated(false)
            let sent = LockIsolated<[ProTUNMessage.Request.PcapRequest]>([])
            let client = Self.client(
                report: .cleared,
                file: .init(url: Self.file, size: 0, created: Self.created),
                removed: removed,
                sent: sent
            )

            await client.stop()

            #expect(removed.value)
            #expect(sent.value == [.stop])
        }

        @Test
        func stoppingARunningCaptureKeepsItsFile() async {
            let removed = LockIsolated(false)
            let sent = LockIsolated<[ProTUNMessage.Request.PcapRequest]>([])
            let client = Self.client(
                report: .recording(since: .distantPast),
                file: .init(url: Self.file, size: 42, created: Self.created),
                removed: removed,
                sent: sent
            )

            await client.stop()

            #expect(!removed.value)
            #expect(sent.value == [.stop])
        }

        @Test
        func stoppingAStartingCaptureKeepsItsPackets() async {
            // A tunnel that never finished connecting still captured its handshake attempts, which is the
            // evidence a user reporting a connection issue wants to hand over.
            let removed = LockIsolated(false)
            let sent = LockIsolated<[ProTUNMessage.Request.PcapRequest]>([])
            let client = Self.client(
                report: .starting,
                file: .init(url: Self.file, size: 512, created: Self.created),
                removed: removed,
                sent: sent
            )

            await client.stop()

            #expect(!removed.value)
            #expect(sent.value == [.stop])
        }

        @Test
        func stoppingAnEndedCaptureKeepsItsFile() async {
            let removed = LockIsolated(false)
            let sent = LockIsolated<[ProTUNMessage.Request.PcapRequest]>([])
            let client = Self.client(
                report: .stopped(.timerHit),
                file: .init(url: Self.file, size: 900, created: Self.created),
                removed: removed,
                sent: sent
            )

            await client.stop()

            #expect(!removed.value)
            #expect(sent.value == [.stop])
        }

        @Test
        func failedWriteAheadUndoesTheStart() async {
            struct SaveFailed: Error {}
            let removed = LockIsolated(false)
            let client = withDependencies {
                $0.extensionIPC.currentPacketCapture = { .cleared }
                $0.extensionIPC.observePacketCapture = { .finished }
                $0.pcapFileManager.createCaptureFile = { Self.file }
                $0.pcapFileManager.removeCaptureFiles = { removed.setValue(true) }
                $0.tunnelMessageSender = TunnelMessageSender { (_: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response in
                    throw .sendingError(.managerUnavailable(SaveFailed()))
                }
            } operation: {
                PacketCaptureClient.liveValue
            }

            await #expect(throws: SaveFailed.self) {
                try await client.start()
            }
            #expect(removed.value)
        }

        @Test
        func unreachableTunnelKeepsTheDeclaredCapture() async throws {
            let removed = LockIsolated(false)
            let client = withDependencies {
                $0.extensionIPC.currentPacketCapture = { .cleared }
                $0.extensionIPC.observePacketCapture = { .finished }
                $0.pcapFileManager.createCaptureFile = { Self.file }
                $0.pcapFileManager.removeCaptureFiles = { removed.setValue(true) }
                $0.tunnelMessageSender = TunnelMessageSender { (_: ProTUNMessage.Request) async throws(ProviderMessageError) -> ProTUNMessage.Response in
                    throw .noDataReceived
                }
            } operation: {
                PacketCaptureClient.liveValue
            }

            try await client.start()
            #expect(!removed.value)
        }

        @Test
        func sessionStreamFollowsTheCaptureReports() async {
            let since = Date(timeIntervalSince1970: 1_755_000_000)
            let current = LockIsolated(PacketCaptureReport.cleared)
            let (reports, reporter) = AsyncStream<PacketCaptureReport>.makeStream()
            let client = withDependencies {
                $0.extensionIPC.currentPacketCapture = { current.value }
                $0.extensionIPC.observePacketCapture = { reports }
                $0.pcapFileManager.captureFile = { .init(url: Self.file, size: 0, created: Self.created) }
            } operation: {
                PacketCaptureClient.liveValue
            }

            current.setValue(.recording(since: since))
            reporter.yield(.recording(since: since))
            reporter.finish()

            var sessions: [CaptureSession] = []
            for await session in client.observeSession() {
                sessions.append(session)
                break
            }
            #expect(sessions == [.sessionStarted(urlWithDate: .init(url: Self.file, date: since))])
        }
    }

    @Suite("Packet capture payload")
    struct PacketCapturePayloadTests {
        @Test(arguments: [
            PacketCaptureInterruptionReason.connectionTerminated, .explicitStop, .timerHit, .storageLimitHit,
        ])
        func stopReasonSurvivesTheRoundTrip(reason: PacketCaptureInterruptionReason) {
            #expect(IPCPacketCapturePayload(.stopped(reason)).packetCaptureReport == .stopped(reason))
        }

        @Test
        func recordingStartSurvivesTheRoundTrip() {
            let since = Date(timeIntervalSince1970: 1_755_000_000.25)
            #expect(IPCPacketCapturePayload(.recording(since: since)).packetCaptureReport == .recording(since: since))
        }

        @Test
        func startingSurvivesTheRoundTrip() {
            #expect(IPCPacketCapturePayload(.starting).packetCaptureReport == .starting)
        }

        @Test
        func zeroedPayloadReadsAsCleared() {
            #expect(IPCPacketCapturePayload().packetCaptureReport == .cleared)
        }
    }

    @Suite("Capture session reader")
    @MainActor
    struct CaptureSessionReaderTests {
        @Reducer
        fileprivate struct Probe {
            @ObservableState
            struct State: Equatable {
                @SharedReader(.captureSession) var captureSession: CaptureSession = .noSession
            }

            enum Action {}

            var body: some Reducer<State, Action> {
                EmptyReducer()
            }
        }

        @Test
        func storeSeedsTheReaderFromTheStubbedClient() {
            let ended = CaptureSession.sessionEnded(urlWithSize: .init(url: URL(filePath: "x.pcap"), size: 9))
            let store = TestStore(initialState: Probe.State()) {
                Probe()
            } withDependencies: {
                $0.packetCaptureClient = .stub(session: ended)
            }
            #expect(store.state.captureSession == ended)
        }
    }
#endif
