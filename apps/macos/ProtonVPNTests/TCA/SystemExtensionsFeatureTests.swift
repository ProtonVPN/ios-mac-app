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
struct SystemExtensionsFeatureTests {
    @Test("Requests are serialized and processed in order")
    func requestsAreSerialized() async {
        let store = TestStore(initialState: SystemExtensionsFeature.State()) {
            SystemExtensionsFeature()
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
            $0.installRequestContext = .init(
                requestID: firstRequest.id,
                includedTypes: [.wireGuard],
                shouldStartTour: true
            )
        }
        await store.receive(\.service.startInstall) {
            $0.service.currentOperation = .install
            $0.service.pendingTypes = [.wireGuard]
        }

        await store.receive(\.service.requestTransitioned) {
            $0.service.states[.wireGuard] = .succeeded(.completed)
            $0.service.pendingTypes = []
        }
        await store.receive(\.service.delegate.installCompleted) {
            $0.installRequestContext = nil
        }
        await store.receive(\.service.clearCurrentOperation) {
            $0.service.currentOperation = nil
            $0.service.pendingTypes = []
            $0.service.states = [:]
            $0.service.approvalRequiredTypes = []
            $0.service.lastNotifiedApprovalTypes = []
        }
        await store.receive(\.completed) {
            $0.inFlightRequestID = nil
            $0.installRequestContext = nil
            $0.completedRequestIDs = [firstRequest.id]
        }
        await store.receive(\.startNextRequest)
        await store.send(.enqueue(secondRequest)) {
            $0.queuedRequests = [secondRequest]
        }
        await store.receive(\.startNextRequest) {
            $0.inFlightRequestID = secondRequest.id
            $0.queuedRequests = []
            $0.installRequestContext = .init(
                requestID: secondRequest.id,
                includedTypes: [.wireGuard, .plutonium],
                shouldStartTour: true
            )
        }
        await store.receive(\.service.startInstall) {
            $0.service.currentOperation = .install
            $0.service.pendingTypes = [.wireGuard, .plutonium]
        }
        await store.receive(\.service.requestTransitioned) {
            $0.service.states[.wireGuard] = .succeeded(.completed)
            $0.service.pendingTypes = [.plutonium]
        }
        await store.receive(\.service.requestTransitioned) {
            $0.service.states[.plutonium] = .succeeded(.completed)
            $0.service.pendingTypes = []
        }
        await store.receive(\.service.delegate.installCompleted) {
            $0.installRequestContext = nil
        }
        await store.receive(\.service.clearCurrentOperation) {
            $0.service.currentOperation = nil
            $0.service.pendingTypes = []
            $0.service.states = [:]
            $0.service.approvalRequiredTypes = []
            $0.service.lastNotifiedApprovalTypes = []
        }
        await store.receive(\.completed) {
            $0.inFlightRequestID = nil
            $0.installRequestContext = nil
            $0.completedRequestIDs = [firstRequest.id, secondRequest.id]
        }
        await store.receive(\.startNextRequest)
    }

    @Test("Check and install requests short-circuit when check is false")
    func checkAndInstallShortCircuitsWhenCheckIsFalse() async {
        let store = TestStore(initialState: SystemExtensionsFeature.State()) {
            SystemExtensionsFeature()
        } withDependencies: {
            $0.propertiesManager.connectionProtocol = .vpnProtocol(.ike)
            $0.systemExtensionsProfilesClient = .init(hasCustomProfilesRequiringSystemExtension: { false })
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
    }

    @Test("Feature interprets approval-path cancellation as tour cancelled")
    func interpretsApprovalPathCancellationAsTourCancelled() async {
        let request = SystemExtensionsRequest(
            origin: .connectionSettings,
            kind: .installOrUpdate(shouldStartTour: true, includedTypes: [.wireGuard])
        )

        let observedResponse = LockIsolated<SystemExtensionsRequestResponse?>(nil)
        let store = TestStore(
            initialState: SystemExtensionsParentFeature.State(
                systemExtensions: .init(
                    inFlightRequestID: request.id,
                    queuedRequests: [],
                    completedRequestIDs: [],
                    installRequestContext: .init(
                        requestID: request.id,
                        includedTypes: [.wireGuard],
                        shouldStartTour: true
                    )
                )
            )
        ) {
            SystemExtensionsParentFeature(
                onCompleted: { _, response in
                    observedResponse.setValue(response)
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.systemExtensions(.installTourCancelled(request.id))) {
            $0.systemExtensions.installRequestContext?.didCancelTour = true
        }
        await store.send(
            .systemExtensions(
                .service(
                    .delegate(
                        .installCompleted(
                            result: .init(
                                accumulated: .success(.alreadyThere),
                                individualResults: [.wireGuard: .success(.alreadyThere)],
                                didRequireUserApproval: true
                            )
                        )
                    )
                )
            )
        ) {
            $0.systemExtensions.installRequestContext = nil
        }
        await store.receive(\.systemExtensions.completed) {
            $0.systemExtensions.inFlightRequestID = nil
            $0.systemExtensions.installRequestContext = nil
            $0.systemExtensions.completedRequestIDs = [request.id]
        }

        guard case let .installation(outcome)? = observedResponse.value else {
            Issue.record("Expected installation response")
            return
        }
        guard case .failure(.tourCancelled) = outcome.accumulated else {
            Issue.record("Expected feature to map approval-path cancellation to tourCancelled, got: \(outcome.accumulated)")
            return
        }
    }
}
