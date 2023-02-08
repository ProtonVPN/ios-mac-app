//
//  Created on 03/02/2023.
//
//  Copyright (c) 2023 Proton AG
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

import UIKit
import SwiftUI

class TelemetryViewController: UIViewController {

    var completion: (() -> Void)?
    var preferenceChangeUsageData: ((Bool) -> Void) = { _ in }
    var preferenceChangeCrashReports: ((Bool) -> Void) = { _ in }

    override func viewDidLoad() {
        super.viewDidLoad()

        // By default, set the telemetry to true
        preferenceChangeUsageData(true)
        preferenceChangeCrashReports(true)

        let telemetryView = TelemetryView(preferenceChangeUsageData: preferenceChangeUsageData,
                                          preferenceCrashReports: preferenceChangeCrashReports,
                                          completion: completion)

        let hostingController = UIHostingController(rootView: telemetryView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)

        hostingController.didMove(toParent: self)

        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
    }
}
