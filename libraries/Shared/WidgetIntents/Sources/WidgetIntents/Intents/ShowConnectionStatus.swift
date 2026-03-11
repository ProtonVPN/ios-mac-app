//
//  Created on 2026-02-10 by Pawel Jurczyk.
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

import AppIntents
import Connection
import Sharing

public struct ShowConnectionStatus: AppIntent {
    public static let title: LocalizedStringResource = "Show connection status"
    static let description = IntentDescription(
        "This intent allows to check the current VPN connection status",
        resultValueName: "protected"
    )

    public static var parameterSummary: some ParameterSummary {
        Summary("Retrieve current VPN connection status")
    }

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        @SharedReader(.connectionState) var connectionState: ConnectionState
        if connectionState.is(\.connected) {
            return .result(value: true, dialog: "You are protected")
        } else {
            return .result(value: false, dialog: "You are not protected")
        }
    }
}
