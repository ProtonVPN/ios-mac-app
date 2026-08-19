//
//  Created on 2022-01-13.
//
//  Copyright (c) 2022 Proton AG
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

@testable import CommonNetworking
import Foundation
import ProtonCoreUtilities
import Testing

@Suite("Bug report model decoding")
struct BugReportModelDecodingTests {
    @Test("Decodes a form in the shape the API sends")
    func decodesAFormInTheShapeTheAPISends() throws {
        let configFile = try #require(Bundle.module.url(forResource: "example1", withExtension: "json"))
        let data = try Data(contentsOf: configFile)

        let model = try JSONDecoder.decapitalisingFirstLetter.decode(BugReportModel.self, from: data)

        #expect(model.categories.first?.label == "Browsing speed_")
        #expect(model.categories.first?.suggestions?.last?.text == "Try a different server. Servers in nearby countries often have faster connection speeds.")
    }

    /// The bundled form is what `.dynamicBugReport` hands out before any download succeeds, so a
    /// file the app cannot decode would leave every user with an empty form.
    @Test("Decodes the form bundled with the app")
    func decodesTheFormBundledWithTheApp() {
        let model = BugReportModel.bundled

        #expect(model.categories.map(\.label) == [
            "Browsing speed",
            "Connecting to VPN",
            "Weak or unstable connection",
            "Using the app",
            "Streaming",
            "Something else",
        ])
        #expect(model.categories.first?.inputFields.first?.label == "Network type")
        #expect(model.categories.last?.suggestions == nil)
    }
}
