//
//  StatusMenuProfileItemViewModel.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa
import Dependencies
import Domain
import LegacyCommon
import Strings
import Theme
import VPNAppCore

class StatusMenuProfileItemViewModel: AbstractProfileViewModel {
    @Dependency(\.sidebarConnectionCommandClient) private var sidebarConnectionCommandClient

    var canConnect: Bool {
        !underMaintenance && canUseProfile
    }

    var icon: ProfileIcon {
        profile.profileIcon
    }

    var name: NSAttributedString {
        let style: AppTheme.Style = canConnect ? .normal : .weak
        return profile.name.styled(style, font: .themeFont(.paragraph), alignment: .left, lineBreakMode: .byTruncatingTail)
    }

    var secondaryDescription: NSAttributedString {
        formSecondaryDescription()
    }

    func connectAction() {
        if canConnect {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            log.debug("Profile in status menu selected. Will connect to profile: \(profile.logDescription)", category: .connectionConnect, event: .trigger)
            let spec = makeConnectionSpec(for: profile)
            sidebarConnectionCommandClient.send(.connect(spec, profile.connectionProtocol, .profile))
        }
    }

    private func formSecondaryDescription() -> NSAttributedString {
        let description: String = if underMaintenance {
            Localizable.maintenance
        } else {
            ""
        }

        return description.styled(.weak, font: .themeFont(.paragraph), alignment: .right)
    }

    private func makeConnectionSpec(for profile: Profile) -> ConnectionSpec {
        let location: ConnectionSpec.Location
        var features: Set<ConnectionSpec.Feature> = []

        switch profile.serverOffering {
        case let .fastest(countryCode):
            if let countryCode {
                location = profile.serverType == .secureCore
                    ? .secureCore(.anyHop(to: countryCode, .fastest))
                    : .country(code: countryCode, order: .fastest)
            } else {
                location = profile.serverType == .secureCore
                    ? .secureCore(.any(.fastest))
                    : .any(.fastest)
            }

        case let .random(countryCode):
            if let countryCode {
                location = profile.serverType == .secureCore
                    ? .secureCore(.anyHop(to: countryCode, .random))
                    : .country(code: countryCode, order: .random)
            } else {
                location = profile.serverType == .secureCore
                    ? .secureCore(.any(.random))
                    : .any(.random)
            }

        case let .custom(serverWrapper):
            let server = serverWrapper.server
            if server.feature.contains(.streaming) {
                features.insert(.streaming)
            }
            if server.feature.contains(.p2p) {
                features.insert(.p2p)
            }
            if server.feature.contains(.tor) {
                features.insert(.tor)
            }

            if server.feature.contains(.secureCore) {
                location = .secureCore(.hop(to: server.exitCountryCode, via: server.entryCountryCode))
            } else {
                location = .exact(
                    .paid,
                    logicalID: server.id,
                    number: server.serverNameComponents.sequence,
                    subregion: server.city,
                    regionCode: server.countryCode
                )
            }
        }

        return .init(location: location, features: features, profileId: profile.id)
    }
}
