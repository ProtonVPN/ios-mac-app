//
//  TroubleshootHostingViewController.swift
//  ProtonVPN - Created on 15.12.2024.
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

import BugReportShared
import SwiftUI
import UIKit

/// UIKit hosting controller for TroubleshootView
/// Use this to integrate the SwiftUI TroubleshootView into a UIKit hierarchy
public final class TroubleshootHostingViewController: UIHostingController<TroubleshootView> {
    private let viewModel: TroubleshootViewModel

    public init(viewModel: TroubleshootViewModel) {
        self.viewModel = viewModel
        let troubleshootView = TroubleshootView(viewModel: viewModel)
        super.init(rootView: troubleshootView)
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
