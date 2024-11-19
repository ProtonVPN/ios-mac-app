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

@available(iOS 17, *)
struct FreeConnectionInfoModal: View {
    var store: StoreOf<FreeConnectionInfoFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            HStack(spacing: .themeSpacing8) {
                Text(Localizable.freeConnectionsModalTitle)
                    .font(.themeFont(.body1(.semibold)))
                    .foregroundColor(Color(.text))
                Spacer()
                IconProvider.cross
            }
            Text(Localizable.freeConnectionsModalDescription)
                .font(.themeFont(.body3(emphasised: false)))
                .foregroundColor(Color(.text))
            Text(Localizable.freeConnectionsModalSubtitle(store.countries.count))
                .font(.themeFont(.body2(emphasised: true)))
                .foregroundColor(Color(.text))

            WrappingHStack(horizontalSpacing: .themeSpacing16, verticalSpacing: .themeSpacing16) {
                ForEach(store.countries, id: \.self) { country in
                    HStack(spacing: .themeSpacing8) {
                        IconProvider.flag(forCountryCode: country.code)?
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 16)
                            .cornerRadius(4)
                            .clipped()
                        Text(country.name)
                            .font(.body3(emphasised: false))
                            .foregroundColor(Color(.text))
                    }
                }
            }
            .padding(.bottom, .themeSpacing12)
            Button {

            } label: {
                Text(Localizable.upgrade)
            }.buttonStyle(PrimaryButtonStyle())
        }

    }
}


@available(iOS 17, *)
#Preview("Free Connection Info", traits: .sizeThatFitsLayout) {
    let countries = [
        FreeConnectionInfoFeature.Country(
            name: "United States",
            code: "US"
        ),
        FreeConnectionInfoFeature.Country(
            name: "Japan",
            code: "JP"
        ),
        FreeConnectionInfoFeature.Country(
            name: "Poland",
            code: "PL"
        ),
        FreeConnectionInfoFeature.Country(
            name: "Netherlands",
            code: "NL"
        ),
        FreeConnectionInfoFeature.Country(
            name: "Romania",
            code: "RO"
        )
    ]
    FreeConnectionInfoModal(
        store: .init(
            initialState: .init(
                countries: countries
            )
        ) {
            FreeConnectionInfoFeature()
        }
    )
    .frame(width: 375)
}

// MARK: - View Helpers

@available(iOS 17, *)
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
