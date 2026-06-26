//
//  StatusMenuWindowModel.swift
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
import Ergonomics
import LegacyCommon
import VPNAppCore

protocol StatusMenuWindowModelFactory {
    func makeStatusMenuWindowModel() -> StatusMenuWindowModel
}

extension DependencyContainer: StatusMenuWindowModelFactory {
    func makeStatusMenuWindowModel() -> StatusMenuWindowModel {
        StatusMenuWindowModel(factory: self)
    }
}

class StatusMenuWindowModel {
    typealias Factory = StatusMenuViewModelFactory
    private let factory: Factory

    @Shared(.sessionStatus) private var sessionStatus: SessionStatus
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool
    @Shared(.connectionState) private var connectionState: ConnectionState

    var contentChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(factory: Factory) {
        self.factory = factory
        startObserving()
    }

    var isSessionEstablished: Bool {
        sessionStatus == .established
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    var statusMenuViewController: StatusMenuViewController {
        let viewModel = factory.makeStatusMenuViewModel()
        return StatusMenuViewController(with: viewModel)
    }

    var statusIcon: StatusIcon {
        guard isSessionEstablished else { return .disconnected }
        switch connectionState {
        case .connected:
            return .connected
        case .connecting, .resolving:
            return .connecting
        case .disconnected, .disconnecting:
            return .disconnected
        }
    }

    var appIcon: AppIcon {
        isSessionEstablished && isConnected ? .active : .disconnected
    }

    var isStatusIconBlinking: Bool {
        connectionState.is(\.connecting) || connectionState.is(\.resolving)
    }

    // MARK: - Private functions

    private func startObserving() {
        $sessionStatus.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.contentChanged?()
            }
            .store(in: &cancellables)

        $secureCoreToggle.publisher
            .sink { [weak self] _ in
                self?.contentChanged?()
            }
            .store(in: &cancellables)

        // Defer the UI update one runloop tick so the `@Shared` `willSet` completes before
        // accessors are read by the view (see HeaderViewModel for the full rationale).
        $connectionState.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.contentChanged?()
            }
            .store(in: &cancellables)
    }
}

/// All possible status menu icons
enum StatusIcon {
    static let margin = 2
    static let size = Int(NSStatusBar.system.thickness) - margin * 2

    case connected
    case disconnected
    case connecting
    case unknown
}

enum AppIcon {
    case active
    case disconnected
}
