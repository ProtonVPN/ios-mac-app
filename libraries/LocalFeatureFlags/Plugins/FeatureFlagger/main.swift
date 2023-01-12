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

enum Action: String, CaseIterable {
    case enable
    case disable
    case embed

    var argumentsCount: Int {
        switch self {
        case .enable, .disable:
            return 2
        case .embed:
            return 1
        }
    }

    var usage: String {
        switch self {
        case .enable:
            return "enable <category> <name>: enable feature by category and name"
        case .disable:
            return "disable <category> <name>: disable feature by category and name"
        case .embed:
            return "embed <path>: create file containing feature flag swift dictionary literal at path"
        }
    }
}

enum PlistError: String, Error, CustomStringConvertible {
    case noTarget = "No such target directory exists."
    case noPlistInside = "The target directory exists, but does not contain a 'FeatureFlags.plist'."

    var description: String {
        rawValue
    }
}

@main
struct FeatureFlagger: CommandPlugin {
    static let featureFlagsPlist = "FeatureFlags.plist"
    static let featureFlagsDict = "FeatureFlags.swift"

    func findPlist(context: PluginContext) throws -> Path {
        guard let plistDir = try context.package.targets(named: ["LocalFeatureFlags"]).first?.directory else {
            throw PlistError.noTarget
        }

        guard try FileManager.default.contentsOfDirectory(atPath: plistDir.string).contains(where: { $0 == Self.featureFlagsPlist }) else {
            throw PlistError.noPlistInside
        }

        return plistDir.appending(subpath: Self.featureFlagsPlist)
    }

    func usage(message: String? = nil) {
        let usage = """
        ff <command>: manipulate local feature flags

        Commands:
        \(Action.allCases.map(\.usage).joined(separator: "\n"))
        """

        if let message {
            print(message)
        }
        print(usage)
    }

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        guard let actionString = arguments.first, let action = Action(rawValue: actionString) else {
            usage(message: "Action should be one of 'enable', 'disable', or 'embed'.")
            return
        }

        // enable "VPN" "TurboEncabulator"
        // disable "VPN" "TestingFeature"
        // embed /Users/dave/FeatureFlags.swift
        guard arguments.count-1 == action.argumentsCount else {
            usage(message: "Wrong number of arguments for command '\(action.rawValue)'")
            return
        }

        let plistPath = try findPlist(context: context)

        let toolArgs: [String]
        switch action {
        case .enable:
            toolArgs = [
                "insert",
                "--type",
                "bool",
                "--key",
                arguments[1],
                "--key",
                arguments[2],
                "--value",
                "true",
                plistPath.string
            ]
        case .disable:
            toolArgs = [
                "remove",
                "--key",
                arguments[1],
                "--key",
                arguments[2],
                plistPath.string
            ]
        case .embed:
            toolArgs = [
                "convert",
                "--format",
                "swift",
                "-o",
                arguments[1],
                plistPath.string,
            ]
        }

        let tool = try context.tool(named: "plistutil")
        let url = URL(string: "file://\(tool.path.string)")

        let process = Process()
        process.executableURL = url
        process.arguments = toolArgs
        try process.run()
    }
}
