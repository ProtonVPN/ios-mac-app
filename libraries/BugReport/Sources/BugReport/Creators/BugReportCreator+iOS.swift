//
//  Created on 2021-12-20.
//
//  Copyright (c) 2021 Proton AG
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

#if canImport(UIKit)
import Foundation
import UIKit
import SwiftUI
import ComposableArchitecture

public protocol BugReportCreator {
    func createBugReportViewController(delegate: BugReportDelegate, colors: Colors) -> UIViewController?
}

public final class iOSBugReportCreator: BugReportCreator { // swiftlint:disable:this type_name
    public init() { }

    public func createBugReportViewController(delegate: BugReportDelegate, colors: Colors) -> UIViewController? {
        CurrentEnv.bugReportDelegate = delegate

        delegate.updateAvailabilityChanged = { available in
            withAnimation {
                CurrentEnv.updateViewModel.updateIsAvailable = available
            }
        }
        delegate.checkUpdateAvailability()

        let reducer = ReportBugFeatureiOS()
        #if DEBUG
            ._printChanges() // Only print changes while debugging
        #endif
        let state = ReportBugFeatureiOS.State(whatsTheIssueState: WhatsTheIssueFeature.State(categories: delegate.model.categories))
        let store = Store(initialState: state,
                          reducer: reducer)
        let rootView = ReportBugView(store: store)

        let controller = UIHostingController(
            rootView: rootView
                .environment(\.colors, colors)
                .preferredColorScheme(.dark)
        )

        controller.overrideUserInterfaceStyle = .dark
        return controller
    }
}
#endif
