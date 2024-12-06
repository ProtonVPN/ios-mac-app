//
//  Created on 18/11/2024.
//
//  Copyright (c) 2024 Proton AG
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
import ComposableArchitecture
import Home
import Strings
import ProtonCoreUIFoundations
import SharedViews
import Localization

@available(iOS 16, *)
@MainActor
struct FreeConnectionInfoModal: View {
    var store: StoreOf<FreeConnectionInfoFeature>

    @State private var sheetHeight: CGFloat = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing16) {
            HStack(spacing: .themeSpacing8) {
                Text(Localizable.freeConnectionsModalTitle)
                    .font(.themeFont(.body1(.semibold)))
                    .foregroundColor(Color(.text))
                Spacer()
                Button {
                    store.send(.dismissButtonTapped)
                } label: {
                    IconProvider.cross
                        .foregroundColor(Color(.icon))
                }

            }
            Text(Localizable.freeConnectionsModalServersDescription(store.countryCodes.count))
                .font(.themeFont(.body3(emphasised: false)))
                .foregroundColor(Color(.text))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
            Text(Localizable.freeConnectionsModalSubtitle(store.countryCodes.count))
                .font(.themeFont(.body2(emphasised: true)))
                .foregroundColor(Color(.text))

            WrappingHStack(horizontalSpacing: .themeSpacing16, verticalSpacing: .themeSpacing16) {
                ForEach(store.countryCodes, id: \.self) { countryCode in
                    HStack(spacing: .themeSpacing8) {
                        IconProvider.flag(forCountryCode: countryCode)?
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 16)
                            .cornerRadius(4)
                            .clipped()
                        Text(LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable)
                            .font(.body3(emphasised: false))
                            .foregroundColor(Color(.text))
                    }
                }
            }
            .padding(.vertical, .themeSpacing8)
            VStack {
                Spacer()
                Button {
                    store.send(.upgradeButtonTapped)
                } label: {
                    Text(Localizable.upgrade)
                }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.top, .themeSpacing24)
        .padding(.bottom, .themeSpacing16)
        .overlay {
            GeometryReader { geometry in
                Color.clear.preference(key: FreeConnectionHeightPreferenceKey.self,
                                       value: geometry.size.height)
            }
        }
        .onPreferenceChange(FreeConnectionHeightPreferenceKey.self) { newHeight in
            sheetHeight = newHeight
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .background(Color(.background, .normal))
    }
}

fileprivate struct FreeConnectionHeightPreferenceKey: ViewDimensionPreferenceKey { }

// MARK: - View Helpers

@available(iOS 16, *)
fileprivate struct WrappingHStack: Layout {
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if lineWidth + subviewSize.width + (lineWidth > 0 ? horizontalSpacing : 0) > proposal.width ?? .infinity {
                width = max(width, lineWidth)
                height += lineHeight + verticalSpacing
                lineWidth = subviewSize.width
                lineHeight = subviewSize.height
            } else {
                lineWidth += subviewSize.width + (lineWidth > 0 ? horizontalSpacing : 0)
                lineHeight = max(lineHeight, subviewSize.height)
            }
        }

        width = max(width, lineWidth)
        height += lineHeight

        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if x + subviewSize.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += subviewSize.width + horizontalSpacing
            lineHeight = max(lineHeight, subviewSize.height)
        }
    }
}

@available(iOS 17, *)
#Preview("Free Connection Info", traits: .sizeThatFitsLayout) {
    FreeConnectionInfoModal(
        store: .init(
            initialState: .init(
                countryCodes: ["US","JP","PL","NL","RO"]
            )
        ) {
            FreeConnectionInfoFeature()
        }
    )
}
