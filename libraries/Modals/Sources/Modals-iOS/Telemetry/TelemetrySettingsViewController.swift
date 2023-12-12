//
//  Created on 07/02/2023.
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

public class TelemetrySettingsViewController: UIViewController {
    var telemetryView: TelemetryTogglesView

    public init(
        preferenceChangeUsageData: @escaping (Bool) -> Void,
        preferenceChangeCrashReports: @escaping (Bool) -> Void,
        usageStatisticsOn: Bool,
        crashReportsOn: Bool,
        title: String? = nil
    ) {
        var usageStatisticsOn = usageStatisticsOn
        var crashReportsOn = crashReportsOn

        self.telemetryView = TelemetryTogglesView(
            usageStatisticsOn: .init(
                get: { usageStatisticsOn },
                set: {
                    usageStatisticsOn = $0
                    preferenceChangeUsageData($0)
                }
            ),
            crashReportsOn: .init(
                get: { crashReportsOn },
                set: {
                    crashReportsOn = $0
                    preferenceChangeCrashReports($0)
                }
            )
        )
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(rootView: telemetryView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)

        hostingController.didMove(toParent: self)

        view.addSubview(hostingController.view)
        view.backgroundColor = .color(.background)
        hostingController.view.backgroundColor = .color(.background)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            // No bottom constraint on purpose, we want the view to be pinned to the top of the available space
        ])
    }
}
