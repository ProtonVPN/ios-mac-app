//
//  Created on 28/04/2026 by Max Kupetskyi.
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

import Combine
import ComposableArchitecture
import Foundation

actor SystemExtensionsCoordinator {
    static let shared = SystemExtensionsCoordinator()

    private struct OutputEvent: Sendable {
        let id: UUID
        let response: SystemExtensionsRequestResponse
    }

    private let outputs = PassthroughSubject<OutputEvent, Never>()
    private var store: StoreOf<SystemExtensionsParentFeature>?

    func installOrUpdate(
        origin: SystemExtensionsRequestOrigin,
        shouldStartTour: Bool,
        includedTypes: [SystemExtensionType]
    ) async -> SystemExtensionsInstallOutcome {
        let request = SystemExtensionsRequest(
            origin: origin,
            kind: .installOrUpdate(shouldStartTour: shouldStartTour, includedTypes: includedTypes)
        )
        let store = await ensureStore()
        let outputStream = outputs.values

        await MainActor.run {
            _ = store.send(.systemExtensions(.enqueue(request)))
        }

        for await output in outputStream where output.id == request.id {
            if case let .installation(outcome) = output.response {
                return outcome
            }
        }

        log.assertionFailure("Install request completed without installation output: \(request.id)")
        return .init(
            accumulated: .failure(.tourCancelled),
            individualResults: Dictionary(
                uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourCancelled)) }
            )
        )
    }

    func checkAndInstallOrUpdate(
        origin: SystemExtensionsRequestOrigin,
        shouldStartTour: Bool,
        includedTypes: [SystemExtensionType]
    ) async -> SystemExtensionsInstallOutcome {
        let request = SystemExtensionsRequest(
            origin: origin,
            kind: .checkAndInstallOrUpdate(shouldStartTour: shouldStartTour, includedTypes: includedTypes)
        )
        let store = await ensureStore()
        let outputStream = outputs.values

        await MainActor.run {
            _ = store.send(.systemExtensions(.enqueue(request)))
        }

        for await output in outputStream where output.id == request.id {
            if case let .installation(outcome) = output.response {
                return outcome
            }
        }

        log.assertionFailure("Check/install request completed without installation output: \(request.id)")
        return .init(
            accumulated: .failure(.tourCancelled),
            individualResults: Dictionary(
                uniqueKeysWithValues: includedTypes.map { ($0, .failure(.tourCancelled)) }
            )
        )
    }

    func uninstallAll(
        origin: SystemExtensionsRequestOrigin,
        userInitiated: Bool,
        timeout: DispatchTime? = nil
    ) async -> DispatchTimeoutResult {
        let request = SystemExtensionsRequest(
            origin: origin,
            kind: .uninstallAll(userInitiated: userInitiated, timeout: timeout)
        )
        let store = await ensureStore()
        let outputStream = outputs.values

        await MainActor.run {
            _ = store.send(.systemExtensions(.enqueue(request)))
        }

        for await output in outputStream where output.id == request.id {
            if case let .uninstall(result) = output.response {
                return result
            }
        }

        log.assertionFailure("Uninstall request completed without uninstall output: \(request.id)")
        return .timedOut
    }

    private func ensureStore() async -> StoreOf<SystemExtensionsParentFeature> {
        if let store {
            return store
        }

        let createdStore = await MainActor.run {
            Store(initialState: SystemExtensionsParentFeature.State()) {
                SystemExtensionsParentFeature { [weak self] id, response in
                    Task {
                        await self?.outputs.send(.init(id: id, response: response))
                    }
                }
            }
        }

        store = createdStore
        return createdStore
    }
}

private enum SystemExtensionsCoordinatorKey: DependencyKey {
    static let liveValue = SystemExtensionsCoordinator.shared
    #if DEBUG
        static let testValue = SystemExtensionsCoordinator.shared
    #endif
}

extension DependencyValues {
    var systemExtensionsCoordinator: SystemExtensionsCoordinator {
        get { self[SystemExtensionsCoordinatorKey.self] }
        set { self[SystemExtensionsCoordinatorKey.self] = newValue }
    }
}
