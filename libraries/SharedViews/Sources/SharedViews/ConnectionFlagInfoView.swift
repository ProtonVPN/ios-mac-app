//
//  Created on 2023-06-30.
//
//  Copyright (c) 2023 Proton AG
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

import SwiftUI
import VPNShared
import Theme
import Dependencies

public struct ConnectionFlagInfoView: View {

    public let location: ConnectionSpec.Location
    @Dependency(\.locale) private var locale

    @ScaledMetric(relativeTo: .body) var topLineHeight: CGFloat = 16

    public init(location: ConnectionSpec.Location) {
        self.location = location
    }

    @ViewBuilder
    var flag: some View {
        switch location {
        case .fastest:
            SimpleFlagView(regionCode: "Fastest", flagSize: .defaultSize)
        case .region(let code):
            SimpleFlagView(regionCode: code, flagSize: .defaultSize)
        case .exact(_, _, _, let code):
            SimpleFlagView(regionCode: code, flagSize: .defaultSize)
        case .secureCore(let secureCoreSpec):
            switch secureCoreSpec {
            case .fastest:
                SecureCoreFlagView(regionCode: "Fastest", viaRegionCode: nil, flagSize: .defaultSize)
            case let .fastestHop(code):
                SecureCoreFlagView(regionCode: code, viaRegionCode: nil, flagSize: .defaultSize)
            case let .hop(code, via):
                SecureCoreFlagView(regionCode: code, viaRegionCode: via, flagSize: .defaultSize)
            }
        }
    }

    public var body: some View {
        HStack(alignment: .top) {
            flag.padding(0)

            VStack(alignment: .leading) {
                Text(location.text(locale: locale))
                    .styled()
#if canImport(Cocoa)
                    .themeFont(.body())
#elseif canImport(UIKit)
                    .themeFont(.body1(.semibold))
#endif
                    .frame(minHeight: topLineHeight)

                if let subtext = location.subtext(locale: locale) {
                    Text(subtext)
                        .styled(.weak)
#if canImport(Cocoa)
                        .themeFont(.body())
#elseif canImport(UIKit)
                        .themeFont(.caption())
#endif
                }
            }.padding(.leading, 8)
        }
    }
}

struct ConnectionFlagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                ConnectionFlagInfoView(location: .fastest)
                Divider()
                ConnectionFlagInfoView(location: .region(code: "US"))
                Divider()
                ConnectionFlagInfoView(location: .exact(.free, number: 1, subregion: nil, regionCode: "US"))
                Divider()
                ConnectionFlagInfoView(location: .exact(.paid, number: 1, subregion: nil, regionCode: "US"))
                Divider()
            }
            ConnectionFlagInfoView(location: .exact(.paid, number: 1, subregion: "AR", regionCode: "US"))
            Divider()
            ConnectionFlagInfoView(location: .secureCore(.fastest))
            Divider()
            ConnectionFlagInfoView(location: .secureCore(.fastestHop(to: "SE")))
            Divider()
            ConnectionFlagInfoView(location: .secureCore(.hop(to: "JP", via: "CH")))

        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}

// MARK: - Model extensions

public extension ConnectionSpec.Location {

    private func regionName(locale: Locale, code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    func accessibilityText(locale: Locale) -> String {
        switch self {
        case .fastest:
            return "The fastest country available"
        case .secureCore(.fastest):
            return "The fastest secure core country available"
        default:
            // todo: .exact and .region should specify number and ideally features as well
            return text(locale: locale)
        }
    }

    func text(locale: Locale) -> String {
        switch self {
        case .fastest,
                .secureCore(.fastest):
            return "Fastest"
        case .region(let code),
                .exact(_, _, _, let code),
                .secureCore(.fastestHop(let code)),
                .secureCore(.hop(let code, _)):
            return regionName(locale: locale, code: code)
        }
    }

    func subtext(locale: Locale) -> String? {
        switch self {
        case .fastest, .region, .secureCore(.fastest), .secureCore(.fastestHop):
            return nil
        case let .exact(server, number, subregion, _):
            if server == .free {
                return "FREE#\(number)"
            } else if let subregion {
                return "\(subregion) #\(number)"
            } else {
                return nil
            }
        case .secureCore(.hop(_, let via)):
            return "via \(regionName(locale: locale, code: via))"
        }
    }
}
