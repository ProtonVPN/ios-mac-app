//
//  Created on 28/04/2026 by Max Kupetskyi.
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

import Dependencies
import DependenciesMacros
import Domain
import Foundation
import LegacyCommon
import VPNAppCore

@DependencyClient
struct SystemExtensionsPresentationClient {
    var showTourAlert: @Sendable (_ origin: SystemExtensionTourAlert.Origin, _ cancelHandler: @escaping () -> Void) -> Void
    var showEnabledAlert: @Sendable () -> Void
    var postTourCancelled: @Sendable () -> Void
    var postAllInstalled: @Sendable (_ didRequireUserApproval: Bool) -> Void
}

extension SystemExtensionsPresentationClient: DependencyKey {
    static let liveValue: SystemExtensionsPresentationClient = .init(
        showTourAlert: { origin, cancelHandler in
            let alertService = (Container.sharedContainer)?.makeCoreAlertService()
            alertService?.push(alert: SystemExtensionTourAlert(origin: origin, cancelHandler: cancelHandler))
        },
        showEnabledAlert: {
            let alertService = (Container.sharedContainer)?.makeCoreAlertService()
            alertService?.push(alert: SysexEnabledAlert())
        },
        postTourCancelled: {
            AppEvent.systemExtensionTourCancelled.post()
        },
        postAllInstalled: { didRequireUserApproval in
            AppEvent.systemExtensionsAllInstalled.post(didRequireUserApproval)
        }
    )

    #if DEBUG
        static let testValue: SystemExtensionsPresentationClient = .init(
            showTourAlert: { _, _ in },
            showEnabledAlert: {},
            postTourCancelled: {},
            postAllInstalled: { _ in }
        )
    #endif
}

extension DependencyValues {
    var systemExtensionsPresentationClient: SystemExtensionsPresentationClient {
        get { self[SystemExtensionsPresentationClient.self] }
        set { self[SystemExtensionsPresentationClient.self] = newValue }
    }
}
