//
//  Created on 19/05/2026 by Chris Janusiewicz.
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
import Foundation
import NetworkExtension

@Reducer
public struct NetworkConfigurationsDebugFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        package var content: Content
        package var newBundleIdentifier: String
        @Presents package var alert: AlertState<Action.Alert>?
        @Presents package var prompt: Prompt?

        package init(
            content: Content = .none,
            newBundleIdentifier: String = ""
        ) {
            self.content = content
            self.newBundleIdentifier = newBundleIdentifier
        }

        public struct Prompt: Equatable, Sendable {
            public init() {}
        }
    }

    package init() {}

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loadConfigurations
        case loadConfigurationsFinished(Result<[NetworkConfigurationInfo], Error>)
        case addConfigurationTapped
        case addConfiguration
        case addConfigurationFinished(Result<Void, Error>)
        case alert(PresentationAction<Alert>)
        case prompt(PresentationAction<PromptAction>)
        case delegate(Delegate)

        public enum Alert: Sendable {
            case cancel
        }

        public enum PromptAction: Sendable {
            case cancel
            case confirm
        }

        public enum Delegate {
            case dismiss
        }
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .loadConfigurations:
                state.content = .loading
                return .run { send in
                    let result = await Result {
                        let ike = NEVPNManager.shared()
                        try await ike.loadFromPreferences()
                        let tunnelManagers = try await NETunnelProviderManager.loadAllFromPreferences()

                        var infos: [NetworkConfigurationInfo] = []
                        if ike.protocolConfiguration != nil {
                            infos.append(NetworkConfigurationInfo(manager: ike))
                        }
                        infos.append(contentsOf: tunnelManagers.map(NetworkConfigurationInfo.init(manager:)))
                        return infos
                    }
                    await send(.loadConfigurationsFinished(result))
                }

            case let .loadConfigurationsFinished(.success(configurations)):
                state.content = .loaded(configurations)
                return .none

            case let .loadConfigurationsFinished(.failure(error)):
                state.content = .failed("\(error)")
                return .none

            case .addConfigurationTapped:
                state.newBundleIdentifier = ""
                state.prompt = State.Prompt()
                return .none

            case .addConfiguration:
                let bundleIdentifier = state.newBundleIdentifier
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                state.newBundleIdentifier = ""
                guard !bundleIdentifier.isEmpty else { return .none }
                return .run { send in
                    let result = await Result {
                        let manager = NETunnelProviderManager()
                        let proto = NETunnelProviderProtocol()
                        proto.providerBundleIdentifier = bundleIdentifier
                        proto.serverAddress = bundleIdentifier
                        manager.protocolConfiguration = proto
                        manager.localizedDescription = "Debug: \(bundleIdentifier)"
                        manager.isEnabled = true
                        try await manager.saveToPreferences()
                    }
                    await send(.addConfigurationFinished(result))
                }

            case .addConfigurationFinished(.success):
                return .send(.loadConfigurations)

            case let .addConfigurationFinished(.failure(error)):
                state.alert = errorAlert(error: error)
                return .none

            case .prompt(.presented(.confirm)):
                return .send(.addConfiguration)

            case .prompt(.presented(.cancel)):
                return .none

            case .prompt(.dismiss):
                state.newBundleIdentifier = ""
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func errorAlert(error: Error) -> AlertState<Action.Alert> {
        AlertState(
            title: { TextState("Failed to add configuration") },
            actions: {
                ButtonState(role: .none, action: .send(.cancel), label: { TextState("Cancel") })
            },
            message: { TextState(String(describing: error)) }
        )
    }
}

public extension NetworkConfigurationsDebugFeature.State {
    @CasePathable
    enum Content: Equatable, Sendable {
        case none
        case loading
        case loaded([NetworkConfigurationInfo])
        case failed(String)
    }
}

public struct NetworkConfigurationInfo: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let isEnabled: Bool
    public let isOnDemandEnabled: Bool
    public let status: String
    public let connectedDate: Date?
    public let kind: Kind
    public let serverAddress: String?
    public let providerBundleIdentifier: String?
    public let providerConfiguration: [Entry]
    public let onDemandRules: [String]

    public enum Kind: String, Sendable {
        case ike = "IKEv2"
        case tunnelProvider = "Tunnel Provider"
        case other = "Other"
    }

    public struct Entry: Equatable, Sendable, Identifiable {
        public let id: String
        public let key: String
        public let value: Value

        public enum Value: Equatable, Sendable {
            case string(String)
            case json(String)

            public var text: String {
                switch self {
                case let .string(value), let .json(value):
                    value
                }
            }
        }

        public init(key: String, value: Value) {
            self.id = key
            self.key = key
            self.value = value
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        isEnabled: Bool,
        isOnDemandEnabled: Bool,
        status: String,
        connectedDate: Date?,
        kind: Kind,
        serverAddress: String?,
        providerBundleIdentifier: String?,
        providerConfiguration: [Entry],
        onDemandRules: [String]
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.isOnDemandEnabled = isOnDemandEnabled
        self.status = status
        self.connectedDate = connectedDate
        self.kind = kind
        self.serverAddress = serverAddress
        self.providerBundleIdentifier = providerBundleIdentifier
        self.providerConfiguration = providerConfiguration
        self.onDemandRules = onDemandRules
    }
}

private extension NetworkConfigurationInfo {
    init(manager: NEVPNManager) {
        let kind: Kind
        let providerBundleIdentifier: String?
        let providerConfiguration: [Entry]

        if let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol {
            kind = .tunnelProvider
            providerBundleIdentifier = tunnelProtocol.providerBundleIdentifier
            providerConfiguration = (tunnelProtocol.providerConfiguration ?? [:])
                .sorted { $0.key < $1.key }
                .map { Entry(key: $0.key, value: Self.describe($0.value)) }
        } else if manager.protocolConfiguration != nil {
            kind = .ike
            providerBundleIdentifier = nil
            providerConfiguration = []
        } else {
            kind = .other
            providerBundleIdentifier = nil
            providerConfiguration = []
        }

        self.init(
            title: manager.localizedDescription ?? "(no title)",
            isEnabled: manager.isEnabled,
            isOnDemandEnabled: manager.isOnDemandEnabled,
            status: manager.connection.status.debugDescription,
            connectedDate: manager.connection.connectedDate,
            kind: kind,
            serverAddress: manager.protocolConfiguration?.serverAddress,
            providerBundleIdentifier: providerBundleIdentifier,
            providerConfiguration: providerConfiguration,
            onDemandRules: (manager.onDemandRules ?? []).map(Self.describe)
        )
    }

    static func describe(_ value: Any) -> Entry.Value {
        if let data = value as? Data {
            if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
               let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8) {
                return .json(pretty)
            }
            if let string = String(data: data, encoding: .utf8) {
                return .string(string)
            }
            return .string("<\(data.count) bytes>")
        }
        return .string(String(describing: value))
    }

    static func describe(_ rule: NEOnDemandRule) -> String {
        let action = switch rule.action {
        case .connect: "connect"
        case .disconnect: "disconnect"
        case .evaluateConnection: "evaluateConnection"
        case .ignore: "ignore"
        @unknown default: "unknown"
        }
        return "\(action) (interfaces: \(rule.interfaceTypeMatch.debugDescription))"
    }
}

private extension NEVPNStatus {
    var debugDescription: String {
        switch self {
        case .invalid: return "invalid"
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .reasserting: return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown (\(rawValue))"
        }
    }
}

private extension NEOnDemandRuleInterfaceType {
    var debugDescription: String {
        switch self {
        case .any: return "any"
        case .ethernet: return "ethernet"
        case .wiFi: return "wifi"
        case .cellular: return "cellular"
        @unknown default: return "unknown (\(rawValue))"
        }
    }
}
#endif
