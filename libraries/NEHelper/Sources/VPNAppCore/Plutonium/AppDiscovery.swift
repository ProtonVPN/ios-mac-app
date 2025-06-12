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

    import Dependencies

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

        public init(bundleIdentifier: String, title: String) {
            self.bundleIdentifier = bundleIdentifier
            self.title = title
        }

        public init?(url: URL) {
            guard let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else { return nil }
            self.bundleIdentifier = bundleIdentifier
            self.title = url.deletingPathExtension().lastPathComponent
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.hashValue == rhs.hashValue
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
        func enumerateAppsFolder() -> [PlutoniumApp] {
            let applicationsURLs = urls(for: .applicationDirectory, in: .allDomainsMask)
            var apps = [PlutoniumApp]()
            for applicationsURL in applicationsURLs {
                do {
                    let contents = try contentsOfDirectory(at: applicationsURL,
                                                           includingPropertiesForKeys: nil,
                                                           options: .skipsSubdirectoryDescendants)
                    let urls = contents
                        .compactMap(PlutoniumApp.init(url:))
                        .uniqued

                    apps.append(contentsOf: urls)
                } catch {
                    log.debug("Couldn't enumerate apps folder: \(applicationsURL), with error: \(error)")
                }
            }

            return apps.uniques(by: \.bundleIdentifier).sorted { $0.title < $1.title }
        }
    }

    public struct AppsProvider {
        public var enumerateAppsFolder: () -> [PlutoniumApp]
    }

    extension AppsProvider: DependencyKey {
        public static let liveValue: AppsProvider = .init(enumerateAppsFolder: FileManager.default.enumerateAppsFolder)

        public static var testValue: AppsProvider = .init { [.huzza] }
    }

    extension DependencyValues {
        public var appsProvider: AppsProvider {
            get { self[AppsProvider.self] }
            set { self[AppsProvider.self] = newValue }
        }
    }

    extension PlutoniumApp {
        static var huzza: PlutoniumApp {
            .init(bundleIdentifier: "test_bundle_id", title: "Huzza!")
        }
    }

#endif
