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

public protocol BugReportCreator {
    var isBugReportAvailable: Bool { get }
    @available(iOS 14.0, *)
    func createBugReportViewController(delegate: BugReportDelegate, colors: Colors?) -> UIViewController?
}

public final class iOSBugReportCreator: BugReportCreator {
    public init() { }
    
    public var isBugReportAvailable: Bool {
        if isNewBugReportEnabled, #available(iOS 14.0.0, *) {
            return true
        }
        return false
    }

    @available(iOS 14.0, *)
    public func createBugReportViewController(delegate: BugReportDelegate, colors: Colors?) -> UIViewController? {
        guard isBugReportAvailable else {
            return nil
        }
        
        Current.bugReportDelegate = delegate

        return UIHostingController(
            rootView: BugReportView()
                .environment(\.colors, colors ?? Colors())
        )
    }
}
#endif
