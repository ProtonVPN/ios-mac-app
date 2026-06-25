//
//  Created on 2026-04-28 by Pawel Jurczyk.
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
import Domain
import Foundation
import SharedErgonomics
import Sharing
import Strings

@Reducer
public struct CaptureVPNSessionFeature {
    @Reducer
    public enum Destination: Equatable {
        case sessionCaptured(SessionCapturedFeature)
    }

    static let minimumStorageCapacity: Int64 = 1024 * 1024 * 200 // 200 MB

    @ObservableState
    public struct State: Equatable {
        @Shared(.captureSession) public var captureSession
        @Presents public var alert: AlertState<Action.Alert>?
        var storageCapacity: Int64?
        @Presents public var destination: Destination.State?

        public var buttonText: String {
            switch captureSession {
            case .noSession:
                Localizable.pcapCaptureSessionStart
            case .sessionStarted:
                Localizable.pcapCaptureSessionStop
            case .sessionEnded:
                Localizable.pcapCaptureSessionCaptureAgain
            }
        }

        public init(destination: Destination.State? = nil) {
            self.destination = destination
        }

        public init(captureSession: CaptureSession) {
            self.$captureSession.withLock {
                $0 = captureSession
            }
        }
    }

    public enum Action {
        case onAppear
        case onDisappear
        case captureButtonPressed
        case alert(PresentationAction<Alert>)
        case captureSessionUpdate(CaptureSession)
        case showErrorMessage(String)
        case destination(PresentationAction<Destination.Action>)
        case togglePacketCapture
        case refreshStorageCapacity

        @CasePathable
        public enum Alert {
            case startCapturing
        }
    }

    private enum CancelID {
        case captureSession
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .showErrorMessage(message):
                state.alert = Self.sessionCaptureFailedAlert(message: message)
                return .none
            case let .captureSessionUpdate(captureSession):
                switch captureSession {
                case .noSession, .sessionStarted:
                    state.destination = nil
                case .sessionEnded:
                    state.destination = .sessionCaptured(.init())
                }
                return .none
            case .onDisappear:
                return .cancel(id: CancelID.captureSession)
            case .onAppear:
                return .merge(
                    .send(.refreshStorageCapacity),
                    .publisher {
                        state.$captureSession
                            .publisher
                            .receive(on: UIScheduler.shared)
                            .removeDuplicates()
                            .map(Action.captureSessionUpdate)
                    }
                    .cancellable(id: CancelID.captureSession)
                )
            case .captureButtonPressed:
                switch state.captureSession {
                case .noSession, .sessionEnded:
                    if let storageCapacity = state.storageCapacity, Self.minimumStorageCapacity > storageCapacity {
                        state.alert = Self.lowStorageAlert
                    } else {
                        state.alert = Self.startCapturingAlert
                    }
                case .sessionStarted:
                    return .send(.togglePacketCapture)
                }
                return .none
            case .alert(.presented(.startCapturing)):
                return .send(.togglePacketCapture)
            case .togglePacketCapture:
                return .run { _ in
                    @Dependency(\.packetCaptureClient) var packetCaptureClient
                    try await packetCaptureClient.togglePacketCapture()
                } catch: { error, send in
                    await send(.showErrorMessage(error.localizedDescription))
                }
            case .destination(.presented(.sessionCaptured(.doneTapped))):
                return .none
            case .destination:
                return .none
            case .alert(.dismiss):
                return .none
            case .refreshStorageCapacity:
                do {
                    @Dependency(\.volumeAvailableCapacity) var volumeAvailableCapacity
                    state.storageCapacity = try volumeAvailableCapacity.capacity()
                } catch {
                    state.storageCapacity = nil
                }
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$destination, action: \.destination)
    }

    static var lowStorageAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.pcapCaptureLowStorage) },
            actions: {
                ButtonState {
                    TextState(Localizable.gotIt)
                }
            },
            message: { TextState(Localizable.pcapCaptureLowStorageActionDescription) }
        )
    }

    static var startCapturingAlert: AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.pcapCaptureSessionShouldStartSession) },
            actions: {
                ButtonState(
                    action: .send(.startCapturing),
                    label: { TextState(Localizable.pcapCaptureSessionStart) }
                )
                ButtonState(
                    role: .cancel,
                    label: { TextState(Localizable.cancel) }
                )
            },
            message: { TextState(Localizable.pcapCaptureSessionIssueReproduction) }
        )
    }

    static func sessionCaptureFailedAlert(message: String) -> AlertState<Action.Alert> {
        AlertState(
            title: { TextState(Localizable.pcapCaptureFailed) },
            actions: {},
            message: { TextState(message) }
        )
    }
}

extension CaptureVPNSessionFeature.Destination.State: Equatable {}
