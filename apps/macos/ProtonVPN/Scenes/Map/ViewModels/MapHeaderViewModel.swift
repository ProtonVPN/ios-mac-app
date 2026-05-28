//
//  MapHeaderViewModel.swift
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
import Combine
import ComposableArchitecture
import Connection
import Domain
import Strings
import Theme
import VPNAppCore

class MapHeaderViewModel {
    @Shared(.connectionState) private var connectionState: ConnectionState
    private var cancellables = Set<AnyCancellable>()

    var contentChanged: (() -> Void)?

    init() {
        // Subscribe to publisher emissions to drive UI re-renders. We don't use `newValue` here
        // because all decisions are made by accessors below, but the sink still must exist to
        // notify the view. The `connectionState` accessors read freshest state by the time the
        // view layer re-renders (post-willSet).
        // Defer the UI update one runloop tick so the `@Shared` `willSet` completes before
        // accessors are read by the view (see HeaderViewModel for the full rationale).
        $connectionState.publisher
            .sink { [weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.contentChanged?()
                }
            }
            .store(in: &cancellables)
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    var description: NSAttributedString {
        let text = (isConnected ? Localizable.connected : Localizable.disconnected).uppercased()
        let style: AppTheme.Style = isConnected ? .link : .danger
        return text.styled(style, font: .themeFont(literalSize: 19, bold: true))
    }

    var isSecureCore: Bool {
        guard let server = connectionState.resolvedServer else {
            return false
        }
        if case .secureCore = server.logical.kind {
            return true
        }
        return false
    }
}
