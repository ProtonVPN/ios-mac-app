//
//  Created on 27/04/2026 by Max Kupetskyi.
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
import Foundation
import LegacyCommon
@testable import ProtonVPN
import Testing

@MainActor
@Suite
struct SystemExtensionsFeatureTests {
    @Test("Requests are serialized and processed in order")
    func requestsAreSerialized() async {
        let gate = AsyncGate()
        let invocationCount = LockIsolated(0)

        let store = TestStore(initialState: SystemExtensionsFeature.State()) {
            SystemExtensionsFeature()
        } withDependencies: {
            $0.systemExtensionsClient = .init(
                installOrUpdateRaw: { _, includedTypes, _ in
                    let currentInvocation = invocationCount.withValue {
                        $0 += 1
                        return $0
                    }

                    if currentInvocation == 1 {
                        await gate.wait()
                    }

                    return SystemExtensionRawInstallationResult(
                        accumulated: .success(.installed),
                        individualResults: Dictionary(
                            uniqueKeysWithValues: includedTypes.map { ($0, .success(.installed)) }
                        ),
                        didRequireUserApproval: false
                    )
                },
                shouldPerformInstallCheck: { true },
                uninstallAll: { _, _ in .success }
            )
        }

        let firstRequest = SystemExtensionsRequest(
            origin: .connectionSettings,
            kind: .installOrUpdate(shouldStartTour: true, includedTypes: [.wireGuard])
        )
        let secondRequest = SystemExtensionsRequest(
            origin: .plutonium,
            kind: .installOrUpdate(shouldStartTour: true, includedTypes: [.wireGuard, .plutonium])
        )

        await store.send(.enqueue(firstRequest)) {
            $0.queuedRequests = [firstRequest]
        }
        await store.receive(\.startNextRequest) {
            $0.inFlightRequestID = firstRequest.id
            $0.queuedRequests = []
        }

        await store.send(.enqueue(secondRequest)) {
            $0.queuedRequests = [secondRequest]
        }

        await gate.open()

        await store.receive(\.completed) {
            $0.inFlightRequestID = nil
            $0.completedRequestIDs = [firstRequest.id]
        }
        await store.receive(\.startNextRequest) {
            $0.inFlightRequestID = secondRequest.id
            $0.queuedRequests = []
        }
        await store.receive(\.completed) {
            $0.inFlightRequestID = nil
            $0.completedRequestIDs = [firstRequest.id, secondRequest.id]
        }
        await store.receive(\.startNextRequest)
    }

    @Test("Check and install requests short-circuit when check is false")
    func checkAndInstallShortCircuitsWhenCheckIsFalse() async {
        let installInvocationCount = LockIsolated(0)
        let checkInvocationCount = LockIsolated(0)

        let store = TestStore(initialState: SystemExtensionsFeature.State()) {
            SystemExtensionsFeature()
        } withDependencies: {
            $0.systemExtensionsClient = .init(
                installOrUpdateRaw: { _, _, _ in
                    installInvocationCount.withValue { $0 += 1 }
                    return SystemExtensionRawInstallationResult(
                        accumulated: .success(.alreadyThere),
                        individualResults: [.wireGuard: .success(.alreadyThere)],
                        didRequireUserApproval: false
                    )
                },
                shouldPerformInstallCheck: {
                    checkInvocationCount.withValue { $0 += 1 }
                    return false
                },
                uninstallAll: { _, _ in .success }
            )
        }

        let request = SystemExtensionsRequest(
            origin: .connectionSettings,
            kind: .checkAndInstallOrUpdate(shouldStartTour: false, includedTypes: [.wireGuard])
        )

        await store.send(.enqueue(request)) {
            $0.queuedRequests = [request]
        }
        await store.receive(\.startNextRequest) {
            $0.inFlightRequestID = request.id
            $0.queuedRequests = []
        }
        await store.receive(\.completed) {
            $0.inFlightRequestID = nil
            $0.completedRequestIDs = [request.id]
        }
        await store.receive(\.startNextRequest)

        #expect(installInvocationCount.value == 0)
        #expect(checkInvocationCount.value == 1)
    }

    @Test("Feature interprets approval-path cancellation as tour cancelled")
    func interpretsApprovalPathCancellationAsTourCancelled() async {
        let request = SystemExtensionsRequest(
            origin: .connectionSettings,
            kind: .installOrUpdate(shouldStartTour: true, includedTypes: [.wireGuard])
        )

        let observedResponse = LockIsolated<SystemExtensionsRequestResponse?>(nil)
        let store = TestStore(
            initialState: SystemExtensionsParentFeature.State()
        ) {
            SystemExtensionsParentFeature(
                onCompleted: { _, response in
                    observedResponse.setValue(response)
                }
            )
        } withDependencies: {
            $0.systemExtensionsClient = .init(
                installOrUpdateRaw: { _, includedTypes, onApprovalRequired in
                    onApprovalRequired(includedTypes)
                    return .init(
                        accumulated: .success(.alreadyThere),
                        individualResults: Dictionary(uniqueKeysWithValues: includedTypes.map { ($0, .success(.alreadyThere)) }),
                        didRequireUserApproval: true
                    )
                },
                shouldPerformInstallCheck: { true },
                uninstallAll: { _, _ in .success }
            )
        }

        await store.send(.systemExtensions(.enqueue(request))) {
            $0.systemExtensions.queuedRequests = [request]
        }
        await store.receive(\.systemExtensions.startNextRequest) {
            $0.systemExtensions.inFlightRequestID = request.id
            $0.systemExtensions.queuedRequests = []
        }
        await store.receive(\.systemExtensions.completed) {
            $0.systemExtensions.inFlightRequestID = nil
            $0.systemExtensions.completedRequestIDs = [request.id]
        }
        await store.receive(\.systemExtensions.startNextRequest)

        guard case let .installation(outcome)? = observedResponse.value else {
            Issue.record("Expected installation response")
            return
        }
        guard case .failure(.tourCancelled) = outcome.accumulated else {
            Issue.record("Expected feature to map approval-path cancellation to tourCancelled, got: \(outcome.accumulated)")
            return
        }
    }

    actor AsyncGate {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isOpen = false

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }
}
