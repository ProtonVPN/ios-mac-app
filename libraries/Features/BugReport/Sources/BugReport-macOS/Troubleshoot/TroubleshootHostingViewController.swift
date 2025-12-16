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

import AppKit
import BugReportShared
import ComposableArchitecture
import Strings
import SwiftUI

/// AppKit hosting controller for TroubleshootView
/// Use this to integrate the SwiftUI TroubleshootView into an AppKit/Cocoa hierarchy
public final class TroubleshootHostingViewController: NSHostingController<TroubleshootView> {
    public init() {
        let store = Store(initialState: .init()) {
            TroubleshootFeature()
        }
        let troubleshootView = TroubleshootView(store: store)
        super.init(rootView: troubleshootView)

        // Set up the dismiss handler after initialization
        rootView = TroubleshootView(store: store, onDismiss: { [weak self] in
            self?.dismiss(nil)
        })
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear() {
        super.viewWillAppear()
        view.window?.title = Localizable.troubleshootTitle
    }
}
