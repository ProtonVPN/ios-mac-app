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

import ComposableArchitecture

import Ergonomics
import VPNAppCore

@Reducer
public struct PlutoniumFeature {

    @ObservableState
    public struct State {
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
            case .disabled(let mode), .enabled(let mode): // compare only the currently selected mode
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

        public init() { }
    }

    public enum Action {
        case toggleModeClicked(Bool)
        case modeSelectionClicked(PlutoniumFeatureToggle.Mode)
        case entryClicked(State.Entry, State.Operation)
        case inputFieldChanged(String)
        case onAppear // discover apps
    }

    public init() { }

    public var body: some Reducer<State, Action> {

        Reduce { state, action in
            switch action {
            case .toggleModeClicked:
                switch state.feature {
                case .disabled(let mode):
                    state.$feature.withLock {
                        $0 = .enabled(mode)
                    }
                case .enabled(let mode):
                    state.$feature.withLock {
                        $0 = .disabled(mode)
                    }
                }
                return .none
            case .entryClicked(let entry, let operation):
                do throws(State.ValidationError) {
                    try state.perform(operation: operation, entry: entry)
                    if operation == .add {
                        state.ipEntry = ""
                    }
                    return .send(.inputFieldChanged(state.ipEntry))
                } catch {
                    switch error {
                    case .invalidIP:
                        state.validationError = .invalidIP
                    case .alreadyExists:
                        state.validationError = .alreadyExists
                    }
                }
                return .none
            case .inputFieldChanged(let input):
                state.ipEntry = input
                state.validationError = nil
                return .none
            case .onAppear:
                @Dependency(\.appsProvider) var appsProvider
                state.discoveredApps = appsProvider.enumerateAppsFolder()

                // Save the configuration when changes apply
                state.$featureApplied.withLock { $0 = state.feature }
                state.$inclusionActivatedApplied.withLock { $0 = state.inclusionActivated }
                state.$exclusionActivatedApplied.withLock { $0 = state.exclusionActivated }
                return .none
            case .modeSelectionClicked(let mode):
                state.$feature.withLock {
                    $0 = .enabled(mode)
                }
                return .none
            }
        }
    }
}

extension PlutoniumFeature.State {
    mutating func perform(operation: Operation, entry: Entry) throws(ValidationError) {
        do {
            switch feature {
            case .disabled:
                log.error("Modifying Plutonium feature while it is disabled is not allowed.")
                return
            case .enabled(let mode):
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
            }
        } catch let error as ValidationError {
            throw error
        } catch {
            // impossible path, need to cover this as `withLock` doesn't rethrow types of errors
        }
    }
}

extension PlutoniumActivated {
    mutating func apply(operation: PlutoniumFeature.State.Operation,
                        entry: PlutoniumFeature.State.Entry) throws(PlutoniumFeature.State.ValidationError) {
        switch entry {
        case .app(let entry):
            switch operation {
            case .add:
                if !apps.contains(entry) {
                    apps.append(entry)
                }
            case .remove:
                apps.removeAll { $0 == entry }
            }
        case .ip(let entry):
            switch operation {
            case .add:
                if ips.contains(entry) {
                    throw .alreadyExists
                }
                guard IPV4Validator(location: entry) == .valid else {
                    throw .invalidIP
                }
                ips.append(entry)
            case .remove:
                ips.removeAll { $0 == entry }
            }
        }
    }
}
