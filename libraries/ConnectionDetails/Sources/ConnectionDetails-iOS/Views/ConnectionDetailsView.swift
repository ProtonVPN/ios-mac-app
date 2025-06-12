//
//  Created on 2023-06-02.
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
import Theme
import ComposableArchitecture
import Strings
import ConnectionDetailsShared
import ProtonCoreUIFoundations
import Domain

struct ConnectionDetailsView: View {
    let store: StoreOf<ConnectionDetailsFeature>

    private enum AccessibilityIdentifiers {
        static let connectionDetailsCountry: String = "connection_details_country"
        static let connectionDetailsCity: String = "connection_details_city"
        static let connectionDetailsServer: String = "connection_details_server"
        static let connectionDetailsProtocol: String = "connection_details_protocol"
    }

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                Text(Localizable.connectionDetailsTitle)
                    .font(.themeFont(.body2()))
                    .foregroundColor(Color(.text, .weak))
                    .padding(.top, .themeSpacing24)
                    .padding(.bottom, .themeSpacing8)

                VStack {
                    VStack(alignment: .leading, spacing: 0) {
                        let connectedSince = store.connectedSince
                        TimelineView(PeriodicTimelineSchedule(from: connectedSince, by: 1)) { _ in
                            Row(title: Localizable.connectionDetailsConnectedFor,
                                contentType: .text(connectedSince.timeIntervalSinceNow.sessionLengthText))
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsCountry, contentType: .text(store.country))
                                .accessibilityIdentifier(
                                    AccessibilityIdentifiers.connectionDetailsCountry
                                )
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        if shouldShowCityRow {
                            Group {
                                Row(title: Localizable.connectionDetailsCity, contentType: .text(store.city))
                                    .accessibilityIdentifier(
                                        AccessibilityIdentifiers.connectionDetailsCity
                                    )
                                Divider().padding([.leading], .themeSpacing8)
                            }
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsServer, contentType: .text(store.server))
                                .accessibilityIdentifier(
                                    AccessibilityIdentifiers.connectionDetailsServer
                                )
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsServerLoad, contentType: .percentage(store.serverLoad))
                        }
                        Group {
                            Divider().padding([.leading], .themeSpacing8)
                            Row(title: Localizable.connectionDetailsProtocol, contentType: .text(store.protocolName))
                                .accessibilityIdentifier(
                                    AccessibilityIdentifiers.connectionDetailsProtocol
                                )
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: .themeRadius12).fill(Color(.background, .normal))
                    )
                }
                .padding(.vertical, .themeSpacing8)
            }
        }
    }

    private var shouldShowCityRow: Bool {
        return store.city != "-" && !store.city.isEmpty
    }

    @MainActor
    struct Row: View {
        let title: String
        let accessory: Accessory
        let content: ContentType

        @Environment(\.dynamicTypeSize) var dynamicTypeSize
        @ScaledMetric var infoIconSize: CGFloat = 16
        @ScaledMetric var infoIconSpacing: CGFloat = .themeSpacing4

        private var standardTypeSize: Bool { dynamicTypeSize <= .xxxLarge }

        enum Accessory {
            case none
            case info
        }

        enum ContentType {
            case text(String)
            case percentage(Int)

            var accessibilityValue: String {
                switch self {
                case let .text(string):
                    return string
                case let .percentage(value):
                    return String(value) + "%"
                }
            }
        }

        init(title: String, contentType: ContentType, accessory: Accessory = .none) {
            self.title = title
            self.accessory = accessory
            self.content = contentType
        }

        var body: some View {
            rowView
                .padding(.vertical, .themeSpacing12)
                .padding(.horizontal, .themeSpacing16)
                .accessibilityElement(children: .combine)
        }

        @ViewBuilder
        private var rowView: some View {
            if standardTypeSize {
                HStack(alignment: .top) {
                    self.titleView
                    Spacer()
                    self.valueView
                }
            } else {
                VStack(alignment: .leading) {
                    self.titleView
                    self.valueView
                }
            }
        }

        private var titleView: some View {
            HStack(spacing: infoIconSpacing) {
                Text(title)
                    .themeFont(.body1())

                if case .info = accessory {
                    IconProvider.infoCircle.resizable().frame(width: infoIconSize, height: infoIconSize)
                }
            }
            .accessibilityLabel(title)
            .foregroundColor(Color(.text, .weak))
        }

        private var valueView: some View {
            HStack(spacing: .themeSpacing8) {
                if case let .percentage(percent) = content {
                    SmallProgressView(percentage: percent)
                }

                switch content {
                case let .text(string):
                    Text(string).themeFont(.body1())
                case let .percentage(percentage):
                    Text(percentage, format: .percent).themeFont(.body1())
                }
            }
            .accessibilityLabel(content.accessibilityValue)
            .foregroundColor(Color(.text, .normal))
        }
    }
}

// MARK: - Previews

struct ConnectionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionDetailsView(store: Store(initialState: .init(connectedSince: Date(timeIntervalSinceNow: -12345),
                                                               country: "Lithuania",
                                                               city: "Siauliai",
                                                               server: "LT#5",
                                                               serverLoad: 23,
                                                               protocolName: "WireGuard"),
                                           reducer: { ConnectionDetailsFeature() }))
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.dark)
    }
}
