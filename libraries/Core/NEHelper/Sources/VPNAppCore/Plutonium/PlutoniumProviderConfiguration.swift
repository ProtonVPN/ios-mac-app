//
//  Created on 25/07/2025 by Shahin Katebi.
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

#if canImport(AppKit)

    import Foundation
    import Sharing

    public struct PlutoniumProviderConfiguration: Codable, Equatable {
        public let plutoniumMode: PlutoniumFeatureToggle.Mode
        public let appIDs: Set<String>
        public let ips: Set<String>
        public let dnsServers: Set<String>

        fileprivate enum Keys: String {
            case plutoniumMode
            case appIDs
            case ips
            case dnsServers
        }

        public init(from dictionary: [String: Any]) throws {
            // Parse mode
            guard let modeString = dictionary[Keys.plutoniumMode.rawValue] as? String else {
                throw PlutoniumConfigurationError.missingMode
            }

            guard let mode = PlutoniumFeatureToggle.Mode(rawValue: modeString) else {
                throw PlutoniumConfigurationError.invalidMode(modeString)
            }
            self.plutoniumMode = mode

            // Parse appIDs
            if let appIDsArray = dictionary[Keys.appIDs.rawValue] as? [String] {
                self.appIDs = Set(appIDsArray)
            } else {
                self.appIDs = []
            }

            // Parse IPs
            if let ipsArray = dictionary[Keys.ips.rawValue] as? [String] {
                self.ips = Set(ipsArray)
            } else {
                self.ips = []
            }

            if let dnsServersArray = dictionary[Keys.dnsServers.rawValue] as? [String] {
                self.dnsServers = Set(dnsServersArray)
            } else {
                self.dnsServers = []
            }
        }
    }

    public enum PlutoniumConfigurationError: Error {
        case missingMode
        case invalidMode(String)
    }

    public extension PlutoniumFeatureToggle {
        func toProviderConfigurationDictionary(dnsServers: [String] = []) async -> [String: Any] {
            let activatedData: PlutoniumActivated = switch mode {
            case .exclusion:
                SharedReader(.exclusionActivated).wrappedValue
            case .inclusion:
                SharedReader(.inclusionActivated).wrappedValue
            }

            @SharedReader(.childBundles) var childBundles: [String: ChildBundle]
            await PlutoniumScanner.shared.waitForScanToComplete()

            // Collect all bundle identifiers (apps + plugins)
            let allBundleIdentifiers = Set(
                activatedData.apps.map(\.bundleIdentifier).reduce(into: [String]()) { partialResult, element in
                    partialResult += [element] + (childBundles[element].map((\.bundleIdentifiers)) ?? [])
                }
            )

            return [
                PlutoniumProviderConfiguration.Keys.plutoniumMode.rawValue: mode.rawValue,
                PlutoniumProviderConfiguration.Keys.appIDs.rawValue: Array(allBundleIdentifiers),
                PlutoniumProviderConfiguration.Keys.ips.rawValue: Array(activatedData.ips),
                PlutoniumProviderConfiguration.Keys.dnsServers.rawValue: dnsServers,
            ]
        }
    }

#endif
