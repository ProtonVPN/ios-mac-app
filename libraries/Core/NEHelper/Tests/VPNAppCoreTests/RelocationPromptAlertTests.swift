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
    import Testing
    import VPNAppCore

    @Suite("Relocation prompt")
    struct RelocationPromptAlertTests {
        @Test("An app in /Applications gets no prompt")
        func applicationsHasNoPrompt() {
            #expect(RelocationPromptAlert(location: .applications, showInFinder: {}, dismissed: {}) == nil)
        }

        @Test(
            "An app in a folder or on the disk image can be shown in Finder",
            arguments: [
                (BundleLocation.downloads, Localizable.relocationPromptMessageFolder),
                (.other, Localizable.relocationPromptMessageFolder),
                (.dmgVolume, Localizable.relocationPromptMessageDiskImage),
            ]
        )
        func folderAndDiskImageOfferFinder(location: BundleLocation, message: String) throws {
            var shownInFinder = false
            var dismissed = false
            let alert = try #require(RelocationPromptAlert(
                location: location,
                showInFinder: { shownInFinder = true },
                dismissed: { dismissed = true }
            ))

            #expect(alert.message == message)
            #expect(alert.actions.map(\.title) == [Localizable.relocationPromptShowInFinder, Localizable.notNow])
            alert.actions.forEach { $0.handler?() }
            #expect(shownInFinder)
            #expect(dismissed)
        }

        @Test("A translocated app explains the steps instead of showing its read-only copy in Finder")
        func translocatedExplainsSteps() throws {
            var shownInFinder = false
            var dismissed = false
            let alert = try #require(RelocationPromptAlert(
                location: .translocated,
                showInFinder: { shownInFinder = true },
                dismissed: { dismissed = true }
            ))

            #expect(alert.message == Localizable.relocationPromptMessageTranslocated)
            #expect(alert.actions.map(\.title) == [Localizable.ok])
            alert.actions.forEach { $0.handler?() }
            #expect(!shownInFinder)
            #expect(dismissed)
        }
    }
#endif
