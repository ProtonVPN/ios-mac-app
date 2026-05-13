//
//  Created on 19/05/2026.
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

#if os(iOS) && DEBUG
    import CommonNetworking
    import CoreConnection
    import Dependencies
    import DependenciesMacros

    public enum ForkSelectorClientError: Error {
        case cancelled
        case sessionForkingFailed(Error)
        case ipcInvalidResponse
    }

    @DependencyClient
    public struct ForkSelectorClient: DependencyKey {
        public internal(set) var pushSelector: () async throws -> Void
    }

    public extension DependencyValues {
        var forkSelectorClient: ForkSelectorClient {
            get { self[ForkSelectorClient.self] }
            set { self[ForkSelectorClient.self] = newValue }
        }
    }

    extension ForkSelectorClient {
        private static let pathStatusCheckingInterval: Duration = .milliseconds(250)
        private static let pathStatusDeadline: Duration = .seconds(2)
        private static let forkingSessionRetriesCount: Int = 3

        struct ForkingExhaustedRetriesError: Swift.Error {}

        private static func retry<Output>(
            count: Int,
            retryDelay: Duration,
            operation: () async throws -> Output
        ) async throws -> Output {
            @Dependency(\.continuousClock) var clock

            var lastError: Error?

            for _ in 0 ..< count {
                try Task.checkCancellation()
                do {
                    return try await operation()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    lastError = error
                    try await clock.sleep(for: retryDelay)
                    continue
                }
            }

            throw lastError ?? ForkingExhaustedRetriesError()
        }

        private static func forkSession(retries: Int) async throws(ForkSelectorClientError) -> String {
            @Dependency(\.sessionService) var sessionService

            do {
                return try await retry(count: retries, retryDelay: .seconds(1)) {
                    try await sessionService.selector(.appContext(.proTUNExtension))
                }
            } catch is CancellationError {
                throw .cancelled
            } catch {
                throw .sessionForkingFailed(error)
            }
        }

        public static let liveValue: ForkSelectorClient = .init {
            do {
                @Dependency(\.tunnelMessageSender) var messageSender
                @Dependency(\.continuousClock) var clock
                @Dependency(\.sessionService) var sessionService
                @Dependency(\.nwStatusStream) var nwStatusStream

                try await nwStatusStream()
                    .when(
                        equals: .satisfied,
                        every: Self.pathStatusCheckingInterval,
                        on: AnyClock(clock),
                        deadline: Self.pathStatusDeadline
                    ) {
                        let selector = try await forkSession(retries: Self.forkingSessionRetriesCount)
                        let response = try await messageSender.sendProTUN(.init(payload: .pushSelector(selector)))
                        guard case .ack = response.payload else {
                            throw ForkSelectorClientError.ipcInvalidResponse
                        }
                    }
            } catch _ as CancellationError {
                throw ForkSelectorClientError.cancelled
            } catch let error as ForkSelectorClientError {
                throw error
            } catch {
                assertionFailure("Pushing selector failed with an unhandled error: \(error)")
                log.error("Pushing selector failed with an unhandled error: \(error)")
                throw ForkSelectorClientError.sessionForkingFailed(error)
            }
        }
    }
#endif
