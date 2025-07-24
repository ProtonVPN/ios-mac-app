//
//  Created on 2025-04-04 by Pawel Jurczyk.
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

import Foundation
import SwiftUI

import ComposableArchitecture

import Domain
import Ergonomics
import Strings
import VPNAppCore

@Reducer
public struct PlutoniumFeature {
    @ObservableState
    public struct State: Equatable {
        @Presents var alert: AlertState<Action.Alert>?

        enum ValidationError: Error {
            case alreadyExists
            case invalidIP
        }

        public enum Operation {
            case add
            case remove
        }

        public enum Entry {
            case app(PlutoniumApp)
            case ip(String)
        }

        @Shared(.plutoniumFeature) var feature: PlutoniumFeatureToggle
        @Shared(.inclusionActivated) var inclusionActivated: PlutoniumActivated
        @Shared(.exclusionActivated) var exclusionActivated: PlutoniumActivated

        @Shared(.plutoniumFeatureApplied) var featureApplied: PlutoniumFeatureToggle
        @Shared(.inclusionActivatedApplied) var inclusionActivatedApplied: PlutoniumActivated
        @Shared(.exclusionActivatedApplied) var exclusionActivatedApplied: PlutoniumActivated

        var requiresReconnection: Bool {
            if case .disabled = feature {
                if case .disabled = featureApplied {
                    return false // if feature was disabled and is still disabled, don't reconnect
                }
            }
            guard feature == featureApplied else {
                return true // if the whole feature enables/disables, reconnect
            }
            switch feature {
            case let .disabled(mode), let .enabled(mode): // compare only the currently selected mode
                switch mode {
                case .exclusion:
                    return exclusionActivated != exclusionActivatedApplied
                case .inclusion:
                    return inclusionActivated != inclusionActivatedApplied
                }
            }
        }

        var discoveredApps: [PlutoniumApp] = []

        var ipEntry: String = ""

        var validationError: ValidationError?

        public init() {}
    }

    @CasePathable
    public enum Action {
        case toggleModeClicked
        case toggleModeConfirmed
        case modeSelectionClicked(PlutoniumFeatureToggle.Mode)
        case entryClicked(State.Entry, State.Operation, PlutoniumFeatureToggle.Mode)
        case inputFieldChanged(String)
        case onAppear // discover apps

        case alert(PresentationAction<Alert>)
        @CasePathable
        public enum Alert {
            case toggleModeConfirmed
        }
    }

    @Shared(.killSwitch) var killSwitch: Bool

    public init() {
        PlutoniumScanner.shared
    }

    static let confirmAlert = AlertState<Action.Alert> {
        TextState(Localizable.turnSplitTunnelingOnTitle)
    } actions: {
        SwiftNavigation.ButtonState(action: .toggleModeConfirmed) {
            TextState(Localizable.continue)
        }
        SwiftNavigation.ButtonState(role: .cancel) {
            TextState(Localizable.notNow)
        }
    } message: {
        TextState(Localizable.turnSplitTunnelingOnDescription)
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .toggleModeClicked:
                // disabling plutonium, all ok
                if case .enabled = state.feature {
                    return .send(.toggleModeConfirmed)
                }
                // kill switch is on, ask to switch it off
                if killSwitch {
                    state.alert = Self.confirmAlert
                    return .none
                }
                // All ok, kill switch is off
                return .send(.toggleModeConfirmed, animation: .default)
            case .toggleModeConfirmed:
                switch state.feature {
                case let .disabled(mode):
                    $killSwitch.withLock {
                        $0 = false
                    }
                    state.$feature.withLock {
                        $0 = .enabled(mode)
                    }
                case let .enabled(mode):
                    state.$feature.withLock {
                        $0 = .disabled(mode)
                    }
                }
                return .none
            case let .entryClicked(entry, operation, mode):
                do throws(State.ValidationError) {
                    try state.perform(operation: operation, entry: entry, mode: mode)
                    if case .ip = entry, operation == .add {
                        state.ipEntry = ""
                        return .send(.inputFieldChanged(state.ipEntry))
                    }
                    return .none
                } catch {
                    switch error {
                    case .invalidIP:
                        state.validationError = .invalidIP
                    case .alreadyExists:
                        state.validationError = .alreadyExists
                    }
                }
                return .none
            case let .inputFieldChanged(input):
                state.ipEntry = input
                state.validationError = nil
                return .none
            case .onAppear:
                @Dependency(\.appsProvider) var appsProvider
                state.discoveredApps = appsProvider.enumerateAppsFolder()

                return .none
            case let .modeSelectionClicked(mode):
                state.$feature.withLock {
                    $0 = .enabled(mode)
                }
                return .none
            case .alert(.presented(.toggleModeConfirmed)):
                return .send(.toggleModeConfirmed)
            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}

extension PlutoniumFeature.State {
    mutating func perform(operation: Operation, entry: Entry, mode: PlutoniumFeatureToggle.Mode) throws(ValidationError) {
        do {
            switch mode {
            case .inclusion:
                try $inclusionActivated.withLock {
                    try $0.apply(operation: operation, entry: entry)
                }
            case .exclusion:
                try $exclusionActivated.withLock {
                    try $0.apply(operation: operation, entry: entry)
                }
            }
        } catch let error as ValidationError {
            throw error
        } catch {
            assertionFailure("Unknown error caught when applying operation \(operation), on entry \(entry): \(error)")
        }
    }
}

extension PlutoniumActivated {
    mutating func apply(
        operation: PlutoniumFeature.State.Operation,
        entry: PlutoniumFeature.State.Entry
    ) throws(PlutoniumFeature.State.ValidationError) {
        switch entry {
        case let .app(entry):
            switch operation {
            case .add:
                if !apps.contains(entry) {
                    apps.append(entry)
                }
            case .remove:
                apps.removeAll { $0 == entry }
            }
        case let .ip(entry):
            switch operation {
            case .add:
                if ips.contains(entry) {
                    throw .alreadyExists
                }
                guard IPv4Validator(location: entry) == .valid else {
                    throw .invalidIP
                }
                ips.append(entry)
            case .remove:
                ips.removeAll { $0 == entry }
            }
        }
    }
}
