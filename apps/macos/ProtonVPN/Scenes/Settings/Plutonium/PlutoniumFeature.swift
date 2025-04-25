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
import Network

import VPNAppCore

@Reducer
public struct PlutoniumFeature {

    @ObservableState
    public struct State {
        enum ValidationError: String {
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
        @Shared(.exclusionActivated)  var exclusionActivated: PlutoniumActivated

        var discoveredApps: [PlutoniumApp] = []

        var remainingApps: [PlutoniumApp] { // UI display
            discoveredApps.filter {
                !activatedApps.contains($0)
            }
        }

        var activatedApps: [PlutoniumApp] { // UI display
            guard case .enabled(let mode) = feature else { return [] }
            switch mode {
            case .inclusion:
                return inclusionActivated.apps
            case .exclusion:
                return exclusionActivated.apps
            }
        }

        var activatedIPs: [String] { // UI display
            guard case .enabled(let mode) = feature else { return [] }
            switch mode {
            case .inclusion:
                return inclusionActivated.ips
            case .exclusion:
                return exclusionActivated.ips
            }
        }

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
                state.perform(operation: operation, entry: entry)
                if operation == .add {
                    state.ipEntry = ""
                }
                return .send(.inputFieldChanged(state.ipEntry))
            case .inputFieldChanged(let input):
                state.ipEntry = input
                state.validationError = nil
                if input.isEmpty {
                    return .none
                }
                guard IPv4Address(input) != nil, input.components(separatedBy: ".").count == 4 else {
                    state.validationError = .invalidIP
                    return .none
                }
                if state.activatedIPs.contains(input) {
                    state.validationError = .alreadyExists
                    return .none
                }
                return .none
            case .onAppear:
                state.discoveredApps = FileManager.enumerateAppsFolder()
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
    mutating func perform(operation: Operation, entry: Entry) {
        switch feature {
        case .disabled:
            return
        case .enabled(let mode):
            switch mode {
            case .inclusion:
                $inclusionActivated.withLock {
                    $0.apply(operation: operation, entry: entry)
                }
            case .exclusion:
                $exclusionActivated.withLock {
                    $0.apply(operation: operation, entry: entry)
                }
            }
        }
    }
}

extension PlutoniumActivated {
    mutating func apply(operation: PlutoniumFeature.State.Operation, entry: PlutoniumFeature.State.Entry) {
        switch entry {
        case .app(let entry):
            switch operation {
            case .add:
                apps.append(entry)
            case .remove:
                apps.removeAll { $0 == entry }
            }
        case .ip(let entry):
            switch operation {
            case .add:
                if !ips.contains(entry) {
                    ips.append(entry)
                }
            case .remove:
                ips.removeAll { $0 == entry }
            }
        }
    }
}
