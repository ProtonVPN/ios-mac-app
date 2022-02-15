//
//  Created on 2022-02-15.
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

import Foundation

/// Merges other LogFileProviders results into one array.
/// Removed duplicates by checking URL's. First added entry takes precedence in case of two entries with the same path.
public class MergeLogFilesProvider: LogFilesProvider {

    private let providers: [LogFilesProvider]

    public init(providers: LogFilesProvider...) {
        self.providers = providers
    }

    public var logFiles: [(String, URL?)] {
        var urlsInResult = Set<URL?>()
        var result = [(String, URL?)]()
        for provider in providers {
            for logFile in provider.logFiles where !urlsInResult.contains(logFile.1) {
                urlsInResult.insert(logFile.1)
                result.append(logFile)
            }
        }
        return result
    }
}
