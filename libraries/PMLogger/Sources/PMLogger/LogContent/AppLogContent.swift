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

import Foundation

/// App logs can be split into several files. This class collects logs from all of them.
public class AppLogContent: LogContent {

    private let folder: URL
    private let filenameWithoutExtension: String = "ProtonVPN"

    public init(folder: URL) {
        self.folder = folder
    }

    private var urls: [URL] {
        let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            .filter { $0.pathComponents.last?.hasMatches(for: "\(filenameWithoutExtension)(.\\d+_[\\d\\w\\-]+)?.log") ?? false }
        return files ?? []
    }

    public func loadContent(callback: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.urls.reduce("", { prev, url in
                guard let contents = try? String(contentsOf: url) else {
                    return prev
                }
                return prev + contents + "\n"
            })
            callback(result)
        }
    }

}
