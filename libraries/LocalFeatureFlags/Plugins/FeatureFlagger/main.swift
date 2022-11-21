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

enum Action: String {
    case enable
    case disable
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        try? write(contentsOf: data)
    }
}

enum PlistError: String, Error, CustomStringConvertible {
    case noTarget = "No such target directory exists."
    case noPlistInside = "The target directory exists, but does not contain a 'FeatureFlags.plist'."
    case noPlist = "Could not get contents of the feature flags plist."
    case badFormat = "Plist was not the correct format."
    case couldntWrite = "Could not open plist file for writing."

    var description: String {
        rawValue
    }
}

@main
struct FeatureFlagger: CommandPlugin {
    static let featureFlagsPlist = "FeatureFlags.plist"

    func plistContents(context: PluginContext) -> (Path, [String: Any])? {
        var stderr = FileHandle.standardError
        let plistPath: Path

        do {
            guard let plistDir = try context.package.targets(named: ["LocalFeatureFlags"]).first?.directory else {
                throw PlistError.noTarget
            }

            guard try FileManager.default.contentsOfDirectory(atPath: plistDir.string).contains(where: { $0 == Self.featureFlagsPlist }) else {
                throw PlistError.noPlistInside
            }

            plistPath = plistDir.appending(subpath: Self.featureFlagsPlist)

            guard let contents = FileManager.default.contents(atPath: plistPath.string) else {
                throw PlistError.noPlist
            }

            var format: PropertyListSerialization.PropertyListFormat = .xml
            guard let plist = try PropertyListSerialization.propertyList(from: contents, format: &format) as? [String: Any] else {
                throw PlistError.badFormat
            }

            return (plistPath, plist)
        } catch {
            print("Could not find FeatureFlags plist file:", String(describing: error), to: &stderr)
            return nil
        }
    }

    func performCommand(context: PluginContext, arguments: [String]) async throws {
        var stderr = FileHandle.standardError

        // enable "VPN" "TurboEncabulator"
        guard arguments.count == 3 else {
            print("Should pass either 'enable' or 'disable', the category, and the feature name.", to: &stderr)
            return
        }

        let (category, feature) = (arguments[1], arguments[2])

        guard let action = Action(rawValue: arguments[0]) else {
            print("Action should be one of 'enable' or 'disable'.", to: &stderr)
            return
        }

        guard let (plistPath, plist) = plistContents(context: context) else {
            return
        }

        var output = plist

        if output[category] == nil {
            output[category] = [String: Any]()
        }

        guard var categoryDict = output[category] as? [String: Any] else {
            print("Category dictionary for '\(category)' is not the correct format.", to: &stderr)
            return
        }

        switch action {
        case .enable:
            categoryDict[feature] = true
            output[category] = categoryDict

        case .disable:
            if categoryDict[feature] != nil {
                categoryDict.removeValue(forKey: feature)

                if categoryDict.isEmpty {
                    output[category] = nil
                } else {
                    output[category] = categoryDict
                }
            }
        }

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: output,
                                                          format: .xml,
                                                          options: 0)

            try FileManager.default.removeItem(atPath: plistPath.string)

            FileManager.default.createFile(atPath: plistPath.string,
                                           contents: data)
        } catch {
            print("Could not serialize feature flag data:",
                  String(describing: error),
                  to: &stderr)
        }
    }
}
