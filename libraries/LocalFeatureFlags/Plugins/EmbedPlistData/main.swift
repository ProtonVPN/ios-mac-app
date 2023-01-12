//
//  Created on 2022-11-21.
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
import PackagePlugin
import os.log

enum PlistError: String, Error, CustomStringConvertible {
    case noTarget = "No such target directory exists."
    case noPlistInside = "The target directory exists, but does not contain a 'FeatureFlags.plist'."

    var description: String {
        rawValue
    }
}

/// EmbedPlistData: de-serialize feature flags at compile time
///
/// `plutil` allows us to convert a plist file directly into a Swift literal dictionary. This lets us sidestep
/// the issue of trying to find the plist as a resource from a swift package, in addition to having a tiny
/// performance benefit.
@main
struct EmbedPlistData: BuildToolPlugin {
    private static let featureFlagsPlist = "FeatureFlags.plist"
    private static let featureFlagsSwift = "FeatureFlags.swift"
    private static let featureFlagsTarget = "LocalFeatureFlags"

    private func plistPath(plistDir: Path) throws -> Path {
        let plistPath: Path

        guard try FileManager.default.contentsOfDirectory(atPath: plistDir.string).contains(where: { $0 == Self.featureFlagsPlist }) else {
            throw PlistError.noPlistInside
        }

        plistPath = plistDir.appending(subpath: Self.featureFlagsPlist)
        return plistPath
    }

    private func plistPath(context: PluginContext) throws -> Path {
        guard let plistDir = try context.package
            .targets(named: [Self.featureFlagsTarget]).first?.directory else {
            throw PlistError.noTarget
        }

        return try plistPath(plistDir: plistDir)
    }

    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {

        let plistPath = try plistPath(context: context)
        let outputPath = context.pluginWorkDirectory.appending(subpath: Self.featureFlagsSwift)

        return [
            .buildCommand(displayName: "Embed local feature flags",
                          executable: try context.tool(named: "plistutil").path,
                          arguments: [
                            "convert",
                            "--format",
                            "swift",
                            "-o",
                            outputPath.string,
                            plistPath.string,
                          ],
                          inputFiles: [plistPath],
                          outputFiles: [outputPath]),
        ]
    }
}
