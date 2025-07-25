//
//  Created on 25/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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
import Foundation

protocol NATPortMappingService: Sendable {
    var portMappingStream: AsyncThrowingStream<PortMappingPacketResponse, Error> { get }
    func createPortMapping(
        gatewayAddress: String,
        portProtocol: PortMappingProtocol,
        internalPort: UInt16,
        externalPort: UInt16,
        currentMappingExpirationDate: Date?
    )
    func cancelPortMapping() async
}

extension NATPortMappingService {
    func startPortMapping(gatewayAddress: String) {
        createPortMapping(
            gatewayAddress: gatewayAddress,
            portProtocol: .udp,
            internalPort: 0,
            externalPort: 0,
            currentMappingExpirationDate: nil
        )
    }
}

final class NATPortMappingServiceImplementation: NATPortMappingService, Sendable {
    static let lifetimePercentageRenewal = 0.75

    private let natPmpClient: NATPortMappingClient
    private let renewalTask: RenewalTaskManager

    public let portMappingStream: AsyncThrowingStream<PortMappingPacketResponse, Error>
    private let portMappingContinuation: AsyncThrowingStream<PortMappingPacketResponse, Error>.Continuation

    // MARK: - Init

    init() {
        self.natPmpClient = NATPortMappingClient()
        let (stream, continuation) = AsyncThrowingStream<PortMappingPacketResponse, Error>.makeStream()
        self.portMappingStream = stream
        self.portMappingContinuation = continuation
        self.renewalTask = RenewalTaskManager()

        // Ensure continuation finishes when deallocated
        continuation.onTermination = { _ in }
    }

    func createPortMapping(
        gatewayAddress: String,
        portProtocol: PortMappingProtocol,
        internalPort: UInt16,
        externalPort: UInt16,
        currentMappingExpirationDate: Date?
    ) {
        Task {
            do {
                let portMappingResponse = try await natPmpClient
                    .requestPortMapping(
                        gatewayAddress: gatewayAddress,
                        portProtocol: portProtocol,
                        internalPort: internalPort,
                        externalPort: externalPort,
                        currentMappingExpirationDate: currentMappingExpirationDate
                    )

                // ensure that BE send success mapping
                guard portMappingResponse.mappedResultCode == .success else {
                    portMappingContinuation.yield(with: .failure(NATPortMappingError.mappingFailed))
                    return
                }

                // Send response to stream
                portMappingContinuation.yield(portMappingResponse)

                // Schedule next renewal if successful
                await scheduleNextRenewal(
                    gatewayAddress: gatewayAddress,
                    response: portMappingResponse
                )
            } catch {
                portMappingContinuation.yield(with: .failure(error))
            }
        }
    }

    func cancelPortMapping() async {
        await renewalTask.cancelRenewal()
    }

    // MARK: - Private

    private func scheduleNextRenewal(
        gatewayAddress: String,
        response: PortMappingPacketResponse
    ) async {
        // we should fire renew during lifetime of a mapping; currently 0.75 * lifetime
        let renewalInterval = TimeInterval(response.mappingLifetime) * Self.lifetimePercentageRenewal
        // calculated expiration date for current mapping
        let currentMappingExpirationDate = Date().addingTimeInterval(TimeInterval(response.mappingLifetime))

        await renewalTask.scheduleRenewal(after: renewalInterval) { [weak self] in
            self?.createPortMapping(
                gatewayAddress: gatewayAddress,
                portProtocol: response.mappedProtocol,
                internalPort: response.internalPort,
                externalPort: response.mappedExternalPort,
                currentMappingExpirationDate: currentMappingExpirationDate
            )
        }
    }
}

// MARK: - Renewal Task Manager

private actor RenewalTaskManager {
    private var currentTask: Task<Void, Never>?

    func scheduleRenewal(after interval: TimeInterval, action: @escaping @Sendable () -> Void) {
        // Cancel any existing renewal task
        currentTask?.cancel()

        // Schedule new renewal
        currentTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    action()
                }
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    func cancelRenewal() {
        currentTask?.cancel()
        currentTask = nil
    }
}

#if DEBUG
    final class NATPortMappingServiceMock: NATPortMappingService {
        init() {}

        var portMappingStream: AsyncThrowingStream<PortMappingPacketResponse, Error> {
            fatalError()
        }

        func createPortMapping(
            gatewayAddress _: String,
            portProtocol _: PortMappingProtocol,
            internalPort _: UInt16,
            externalPort _: UInt16,
            currentMappingExpirationDate _: Date?
        ) {}

        func cancelPortMapping() async {}
    }
#endif

enum NATPortMappingServiceKey: DependencyKey {
    static let liveValue: NATPortMappingService = NATPortMappingServiceImplementation()
    #if DEBUG
        static let testValue: NATPortMappingService = NATPortMappingServiceMock()
    #endif
}

extension DependencyValues {
    var natPortMappingService: NATPortMappingService {
        get { self[NATPortMappingServiceKey.self] }
        set { self[NATPortMappingServiceKey.self] = newValue }
    }
}
