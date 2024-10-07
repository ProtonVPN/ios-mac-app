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
import ConnectionDetails
import ProtonCoreUIFoundations
import Domain

struct ConnectionDetailsView: View {
    let store: StoreOf<ConnectionDetailsFeature>
    
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
                        TimelineView(PeriodicTimelineSchedule(from: .now, by: 1)) { _ in
                            Row(title: Localizable.connectionDetailsConnectedFor,
                                value: connectedSince.timeIntervalSinceNow.sessionLengthText)
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsCountry, value: store.country)
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsCity, value: store.city)
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsServer, value: store.server)
                            Divider().padding([.leading], .themeSpacing8)
                        }
                        Group {
                            Row(title: Localizable.connectionDetailsServerLoad, value: "\(store.serverLoad)%", titleType: .info, contentType: .percentage(store.serverLoad))
                        }
                        Group {
                            Divider().padding([.leading], .themeSpacing8)
                            Row(title: Localizable.connectionDetailsProtocol, value: store.protocolName, titleType: .info)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: .themeRadius12)
                        .fill(Color(.background, .normal)))
                }
                .padding(.vertical, .themeSpacing8)
            }
        }
    }
    
    struct Row: View {
        let title: String
        let value: String
        let titleType: TitleType
        let contentType: ContentType
        
        @Environment(\.dynamicTypeSize) var dynamicTypeSize
        @ScaledMetric var infoIconSize: CGFloat = 16
        @ScaledMetric var infoIconSpacing: CGFloat = .themeSpacing4
        private var standardTypeSize: Bool { dynamicTypeSize <= .xxxLarge }
        
        enum TitleType {
            case simple
            case info
        }
        
        enum ContentType {
            case text
            case percentage(Int)
        }
        
        init(title: String, value: String, titleType: TitleType = .simple, contentType: ContentType = .text) {
            self.title = title
            self.value = value
            self.titleType = titleType
            self.contentType = contentType
        }
        
        var body: some View {
            AnyView(rowView) // Without AnyView next lines won't compile
                .accessibilityLabel(title) // todo: test how this works
                .accessibilityLabel(value)
                .padding(.vertical, .themeSpacing12)
                .padding(.horizontal, .themeSpacing16)
        }
        
        @ViewBuilder
        var rowView: any View {
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
        
        var titleView: some View {
            HStack(spacing: infoIconSpacing) {
                Text(title)
                    .themeFont(.body1())
                
                if case titleType = TitleType.info {
                    IconProvider.infoCircle.resizable().frame(width: infoIconSize, height: infoIconSize)
                }
            }.foregroundColor(Color(.text, .weak))
        }
        
        var valueView: some View {
            HStack(spacing: .themeSpacing8) {
                if case let ContentType.percentage(percent) = contentType {
                    SmallProgressView(percentage: percent)
                }
                
                Text(value)
                    .themeFont(.body1())
                
            }
            .foregroundColor(Color(.text, .normal))
        }
    }
}
// MARK: - Previews

struct ConnectionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionDetailsView(store: Store(initialState: .init(connectedSince: Date.init(timeIntervalSinceNow: -12345),
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
