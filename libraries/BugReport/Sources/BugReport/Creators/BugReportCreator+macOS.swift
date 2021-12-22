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

#if os(macOS)
import Foundation
import AppKit
import SwiftUI

public protocol BugReportCreator {
    func createBugReportViewController(model: BugReportModel, colors: Colors?) -> NSViewController?
}

public final class macOSBugReportCreator: BugReportCreator {
    public init() { }

    public func createBugReportViewController(model: BugReportModel, colors: Colors?) -> NSViewController? {
        guard isNewBugReportEnabled, #available(macOS 11, *) else {
            return nil
        }

        return NSHostingController(rootView: BugReportView(model: model).frame(width: 600, height: 600, alignment: .center))
    }
}
#endif
