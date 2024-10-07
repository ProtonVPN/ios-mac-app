//
//  Created on 22.05.23.
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

import Foundation
import SwiftUI

import ComposableArchitecture

import Domain
import Home
import Strings
import Theme
import VPNAppCore
import SharedViews
import ProtonCoreUIFoundations

@available(iOS 17, *)
public struct RecentsSectionView: View {
    let store: StoreOf<RecentsFeature>

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Localizable.homeRecentsRecentSection)
                .themeFont(.caption())
                .styled(.weak)
                .padding([.top, .leading, .trailing], .themeSpacing16)
                .padding(.bottom, .themeSpacing8)
            WithPerceptionTracking {
                ForEach(store.connections) { item in
                    RecentRowItemView(item: item, sendAction: { _ = store.send($0) })
                }
            }
        }
        .task {
            store.send(.watchConnectionStatus)
        }
    }
}

struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
            configuration.title
        }
    }
}

extension DragGesture.Value {
    /// Ratios as a percentage of the view width for certain swipe/button behaviors.
    enum ThresholdRatio: CGFloat {
        /// How far should we swipe before leaving the button exposed?
        case exposeButton = 0.15
        /// How far should we swipe before performing the action?
        case performAction = 0.5
    }

    func reached(_ threshold: ThresholdRatio, accordingTo viewSize: CGSize) -> Bool {
        let thresholdWidth = threshold.rawValue * viewSize.width

        return abs(translation.width) > thresholdWidth
    }
}

@available(iOS 17, *)
extension RecentsFeature.Action {
    var text: Text {
        let words: String
        switch self {
        case .delegate(.connect):
            words = Localizable.actionConnect
        case .pin:
            words = Localizable.actionHomePin
        case .unpin:
            words = Localizable.actionHomeUnpin
        case .remove:
            words = Localizable.actionRemove
        default:
            words = ""
        }

        return Text(words)
            .themeFont()
            .styled(.inverted)
    }

    var icon: Image? {
        switch self {
        case .pin:
            return IconProvider.pinFilled
        case .unpin:
            return IconProvider.pinSlashFilled
        case .remove:
            return IconProvider.trash
        default:
            return nil
        }
    }

    var color: Color? {
        switch self {
        case .pin, .unpin:
            return .init(.background, [.warning, .weak])
        case .remove:
            return .init(.background, .danger)
        default:
            return nil
        }
    }

    var role: ButtonRole? {
        switch self {
        case .remove:
            return .destructive
        default:
            return nil
        }
    }

    var label: any View {
        guard let icon else {
            return text
        }

        return Label {
            text
        } icon: {
            icon
                .resizable()
                .styled(.inverted)
                .frame(width: 16, height: 16) // todo: this doesn't change size with dynamic type
        }
        .labelStyle(VerticalLabelStyle())
    }
}

//#if DEBUG
//@available(iOS 17, *)
//#Preview {
//    let store: StoreOf<RecentsFeature> = .init(initialState:
//            .init(connections: [
//                RecentConnection(
//                    pinned: true,
//                    underMaintenance: false,
//                    connectionDate: .now,
//                    connection: .init(location: .fastest, features: [])
//                ),
//                RecentConnection(
//                    pinned: true,
//                    underMaintenance: false,
//                    connectionDate: .now,
//                    connection: .init(location: .region(code: "CH"), features: [])
//                ),
//                RecentConnection(
//                    pinned: false,
//                    underMaintenance: false,
//                    connectionDate: .now,
//                    connection: .init(location: .region(code: "US"), features: [])
//                ),
//                RecentConnection(
//                    pinned: false,
//                    underMaintenance: false,
//                    connectionDate: .now,
//                    connection: .init(location: .secureCore(.fastestHop(to: "AR")), features: [])
//                ),
//                RecentConnection(
//                    pinned: false,
//                    underMaintenance: false,
//                    connectionDate: .now,
//                    connection: .init(location: .secureCore(.hop(to: "FR", via: "CH")), features: [])
//                ),
//            ],
//                  connectionStatus: .init()),
//                                            reducer: { RecentsFeature() }
//    )
//    return ScrollView {
//        RecentsSectionView(
//            items: store.remainingConnections,
//            sendAction: { _ = store.send($0) }
//        )
//    }
//    .background(Color(.background, .normal))
//}
//#endif
