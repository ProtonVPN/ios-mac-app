//
//  Created on 18/08/2026 by Max Kupetskyi.
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

import Foundation
import ProtonCoreUtilities

public extension BugReportModel {
    /// The bug report form shipped inside the app, in BugReportConfig.json.
    ///
    /// The apps show this form until they download the current one from the API. `BugReportConfig.json`
    /// uses the same capitalized keys the API sends, so both paths decode through the same
    /// `JSONDecoder.decapitalisingFirstLetter`. An unreadable file leaves the form empty.
    static let bundled: BugReportModel = {
        guard let configFile = Bundle.module.url(forResource: "BugReportConfig", withExtension: "json") else {
            log.error(
                "BugReportConfig.json is missing from the bundle, the bug report form will be empty",
                category: .app
            )
            return BugReportModel()
        }
        do {
            let data = try Data(contentsOf: configFile)
            return try JSONDecoder.decapitalisingFirstLetter.decode(BugReportModel.self, from: data)
        } catch {
            log.error(
                "BugReportConfig.json could not be decoded, the bug report form will be empty",
                category: .app,
                metadata: ["error": "\(error)"]
            )
            return BugReportModel()
        }
    }()
}
