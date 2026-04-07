//
//  Created on 2022-05-23.
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

import Dependencies
import Foundation

public struct LogContentProvider {
    var getLogData: (LogSource) -> LogContent
    #if os(iOS) && DEBUG
        var getArchive: (LogSource) -> LogArchiveContent = { _ in
            fatalError("getArchive not provided for this source")
        }
    #endif

    public init(
        getLogData: @escaping (LogSource) -> LogContent
    ) {
        self.getLogData = getLogData
    }

    #if os(iOS) && DEBUG
        public init(
            getLogData: @escaping (LogSource) -> LogContent,
            getArchive: @escaping (LogSource) -> LogArchiveContent,
        ) {
            self.getLogData = getLogData
            self.getArchive = getArchive
        }
    #endif
}

public extension LogContentProvider {
    func getLogData(for source: LogSource) -> LogContent {
        getLogData(source)
    }

    #if os(iOS) && DEBUG
        func getArchive(for source: LogSource) -> LogArchiveContent {
            getArchive(source)
        }
    #endif
}

extension LogContentProvider: TestDependencyKey {
    public static var testValue: LogContentProvider = {
        fatalError("\(Self.self) must have a implementation")
    }()
}

public extension DependencyValues {
    var logContentProvider: LogContentProvider {
        get { self[LogContentProvider.self] }
        set { self[LogContentProvider.self] = newValue }
    }
}
