//
//  Created on 2025-04-30 by Pawel Jurczyk.
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

import Cocoa

import ComposableArchitecture

import LegacyCommon
import Strings
import VPNAppCore

class PlutoniumWindowController: WindowController {
    typealias Factory = CoreAlertServiceFactory & PropertiesManagerFactory & VpnGatewayFactory

    let store: StoreOf<PlutoniumFeature>

    private let alertService: CoreAlertService
    private let vpnGateway: VpnGatewayProtocol
    private let propertiesManager: PropertiesManagerProtocol

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    required init(factory: Factory) {
        self.alertService = factory.makeCoreAlertService()
        self.vpnGateway = factory.makeVpnGateway()
        self.propertiesManager = factory.makePropertiesManager()

        let shouldSwitchOn: (() async -> Bool) = { [propertiesManager, alertService] in
            await withCheckedContinuation { continuation in
                if !propertiesManager.killSwitch {
                    continuation.resume(returning: true)
                    return
                }
                let alert = PlutoniumConflictAlert {
                    propertiesManager.killSwitch = false
                    continuation.resume(returning: true)
                } cancelHandler: {
                    continuation.resume(returning: false)
                }
                alertService.push(alert: alert)
            }
        }

        let state = PlutoniumFeature.State()
        self.store = StoreOf<PlutoniumFeature>(initialState: state) {
            PlutoniumFeature(shouldSwitchOn: shouldSwitchOn)
        }
        let viewController: NSViewController = .plutonium(store: store)
        let window = NSWindow(contentViewController: viewController)
        super.init(window: window)

        setupWindow()
        monitorsKeyEvents = true
    }

    private func setupWindow() {
        guard let window else {
            return
        }

        window.styleMask.remove(NSWindow.StyleMask.resizable)
        window.title = Localizable.preferences
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .color(.background)
    }

    override func windowWillClose(_: Notification) {
        guard vpnGateway.connection != .disconnected,
              store.requiresReconnection else {
            return
        }
        alertService.push(alert: ReconnectOnActionAlert(
            actionTitle: Localizable.changeSettings,
            confirmHandler: { [weak self] in
                guard let self else { return }
                if vpnGateway.connection != .disconnected {
                    vpnGateway.retryConnection()
                }
            },
            cancelHandler: {}
        ))
    }
}
