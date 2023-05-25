//
//  Created on 01.06.23.
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
import Theme
import Home

struct HomeMapView: View {
    static let bottomGradientHeight: CGFloat = 100
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                HomeAsset.mainMap.swiftUIImage
                    .resizable(resizingMode: .stretch)
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .frame(width: proxy.size.width, height: proxy.mapHeight)
                    .clipped()
                    .offset(y: proxy.mapOffset)

                LinearGradient(
                    colors: [.clear, Color(.background)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                    .frame(height: Self.bottomGradientHeight)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension GeometryProxy {
    var mapOffset: CGFloat {
        let offset = scrollOffset
        return offset > 0 ? -offset : 0
    }

    var mapHeight: CGFloat {
        return size.height - mapOffset
    }
}
