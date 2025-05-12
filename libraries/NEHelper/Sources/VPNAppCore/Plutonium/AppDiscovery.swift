//
//  Created on 2025-05-05 by Pawel Jurczyk.
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

#if canImport(AppKit)

import AppKit
import SwiftUI

import Ergonomics

public struct PlutoniumApp: Identifiable, Hashable, Codable, Equatable {

    public var id: String { bundleIdentifier }

    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }

    public let bundleIdentifier: String
    public var title: String
    public var icon: Image {
        NSWorkspace.shared.icon(application: bundleIdentifier)
    }

    init?(url: URL) {
        guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return nil }
        self.bundleIdentifier = bundleIdentifier
        self.title = url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - App Icons

extension NSWorkspace {

    func icon(application: String) -> Image {
        guard let path = urlForApplication(withBundleIdentifier: application) else {
            return Image(nsImage: icon(for: .application))
        }
        return Image(nsImage: icon(forFile: path.absolutePath))
    }
}

public extension FileManager {
    static func enumerateAppsFolder() -> [PlutoniumApp] {
        let fileManager = FileManager.default
        let applicationsURLs = fileManager.urls(for: .applicationDirectory, in: .allDomainsMask)
        var apps = [PlutoniumApp]()
        for applicationsURL in applicationsURLs {
            do {
                let contents = try fileManager.contentsOfDirectory(at: applicationsURL,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: .skipsSubdirectoryDescendants)
                let urls = contents
                    .compactMap(PlutoniumApp.init(url:))
                    .uniqued

                apps.append(contentsOf: urls)
            } catch {
                log.debug("Couldn't enumerate apps folder: \(applicationsURL), with error: \(error.localizedDescription)")
            }
        }

        return apps.uniques(by: \.bundleIdentifier).sorted { $0.title < $1.title }
    }
}

#endif
