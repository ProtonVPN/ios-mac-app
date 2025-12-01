//
//  Created on 01/12/2025 by Max Kupetskyi.
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

import Dependencies
import UIKit

public struct WelcomeFlowPresenter {
    public var present: (_ initialError: String?, _ overlayViewController: UIViewController?, _ showWelcome: @escaping (String?, UIViewController?) -> Void) -> Void

    public init(
        present: @escaping (_ initialError: String?, _ overlayViewController: UIViewController?, _ showWelcome: @escaping (String?, UIViewController?) -> Void) -> Void
    ) {
        self.present = present
    }
}

extension WelcomeFlowPresenter: TestDependencyKey {
    public static let testValue = WelcomeFlowPresenter { initialError, overlayViewController, showWelcome in
        showWelcome(initialError, overlayViewController)
    }
}

public extension DependencyValues {
    var welcomeFlowPresenter: WelcomeFlowPresenter {
        get { self[WelcomeFlowPresenter.self] }
        set { self[WelcomeFlowPresenter.self] = newValue }
    }
}
