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
import Dependencies

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
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                Text(Localizable.homeRecentsRecentSection)
                    .themeFont(.caption())
                    .styled(.weak)
                    .padding([.top, .leading, .trailing], .themeSpacing16)
                    .padding(.bottom, .themeSpacing8)
                ForEach(store.recents) { item in
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

    @ViewBuilder
    var label: some View {
        if let icon {
            Label {
                text
            } icon: {
                icon
                    .resizable()
                    .styled(.inverted)
                    .frame(.square(.themeSpacing16)) // this doesn't change size with dynamic type
            }
            .labelStyle(VerticalLabelStyle())
        } else {
            text
        }
    }
}

#if DEBUG && compiler(>=6)
@available(iOS 18, *)
#Preview(traits: .dependencies { $0.recentsStorage = .previewValue }) {
    let store: StoreOf<RecentsFeature> = .init(
        initialState: .init(),
        reducer: RecentsFeature.init
    )
    return ScrollView {
        RecentsSectionView(store: store)
    }
    .background(Color(.background, .normal))
}
#endif
