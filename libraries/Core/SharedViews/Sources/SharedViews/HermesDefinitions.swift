//
//  Created on 22/04/2025 by adam.
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

#if os(macOS)
    import AppKit
    import SwiftUI

    public protocol ExplicitlySizedView: View {
        static var viewSize: CGSize { get }
    }

    public class ExplicitlySizedHostingController: NSViewController {
        private(set) var viewSize: CGSize

        private let hostingViewController: NSViewController

        public init<Content: ExplicitlySizedView>(rootView: Content) {
            self.hostingViewController = NSHostingController(rootView: rootView)
            self.viewSize = Content.viewSize
            super.init(nibName: nil, bundle: nil)
            addChild(hostingViewController)
            view = hostingViewController.view
        }

        @available(*, unavailable)
        public required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
#endif
