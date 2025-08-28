//
//  Created on 2025-08-28 by Pawel Jurczyk.
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

import SwiftUI

import Domain
import SharedViews
import Strings
import Theme

public struct NoConnectionsAvailableView: View {
    @Environment(\.dismiss) var dismiss

    public enum Mode {
        case noServers
        case loadingError
        case connectionsDisabled
    }

    let mode: Mode

    public init(mode: Mode) {
        self.mode = mode
    }

    public var body: some View {
        VStack(spacing: .themeSpacing24) {
            Asset.globeError.swiftUIImage
            VStack(spacing: .themeSpacing8) {
                Text(Localizable.noConnectionsAvailable)
                    .font(.headline)
                    .foregroundStyle(Color(.text))
                Text(mode.subtitle)
                    .font(.body2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.center)
            }
            Button(Localizable.subuserAlertLoginButton) {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            if let helpString = mode.helpString {
                Text(helpString)
                    .font(.caption(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .background(Color(.background))
    }
}

extension NoConnectionsAvailableView.Mode {
    var subtitle: String {
        switch self {
        case .noServers, .connectionsDisabled:
            Localizable.noServersSubtitle
        case .loadingError:
            Localizable.serversLoadingErrorSubtitle
        }
    }

    var helpString: LocalizedStringResource? {
        switch self {
        case .connectionsDisabled:
            .init(stringLiteral: Localizable.noServersHelpString(VPNLink.assignVPNConnections.rawValue))
        case .loadingError:
            .init(stringLiteral: Localizable.noServersContactUs(VPNLink.contact.rawValue))
        case .noServers:
            nil
        }
    }
}

#Preview {
    NoConnectionsAvailableView(mode: .noServers)
}

#Preview {
    NoConnectionsAvailableView(mode: .connectionsDisabled)
}

#Preview {
    NoConnectionsAvailableView(mode: .loadingError)
}
