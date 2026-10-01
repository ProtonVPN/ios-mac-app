//
//  Created on 01/10/2026 by Max Kupetskyi.
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

#if os(macOS)
    import Domain
    import Strings

    /// Tells the user to move the app to `/Applications`, where macOS lets it activate its system extensions.
    public final class RelocationPromptAlert: SystemAlert {
        public var title: String? = Localizable.relocationPromptTitle
        public var message: String?
        public var actions = [AlertAction]()
        public let isError = false
        public var dismiss: (() -> Void)?

        /// Creates the prompt for an app that runs from `location`, or nil when the app is in `/Applications`.
        ///
        /// A translocated app gets no Show in Finder button, because Finder would show the read-only copy that macOS
        /// runs instead of the app the user can move.
        public init?(location: BundleLocation, showInFinder: @escaping () -> Void, dismissed: @escaping () -> Void) {
            let showInFinderAction = AlertAction(
                title: Localizable.relocationPromptShowInFinder,
                style: .confirmative,
                handler: showInFinder
            )
            let notNowAction = AlertAction(title: Localizable.notNow, style: .cancel, handler: dismissed)

            switch location {
            case .applications:
                return nil
            case .downloads, .other:
                self.message = Localizable.relocationPromptMessageFolder
                self.actions = [showInFinderAction, notNowAction]
            case .dmgVolume:
                self.message = Localizable.relocationPromptMessageDiskImage
                self.actions = [showInFinderAction, notNowAction]
            case .translocated:
                self.message = Localizable.relocationPromptMessageTranslocated
                self.actions = [AlertAction(title: Localizable.ok, style: .cancel, handler: dismissed)]
            }
        }
    }
#endif
