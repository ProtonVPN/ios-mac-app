//
//  Created on 11/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import SwiftUI
import Theme

/// How busy the connected server is, drawn as a ring with a coloured segment.
///
/// The segment starts at the top and runs clockwise. Loads under 15% still draw a short segment, so
/// the ring never looks empty.
struct LoadCircleView: View {
    let load: Int

    var body: some View {
        ZStack {
            Circle()
                .inset(by: Dimensions.ringInset)
                .stroke(Color(.icon, .hint), lineWidth: Dimensions.ringWidth)

            Circle()
                .inset(by: Dimensions.segmentInset)
                .trim(from: 0, to: segmentPortion)
                .stroke(Color(.icon, style), lineWidth: Dimensions.segmentWidth)
                .rotationEffect(.degrees(-90))
        }
        .frame(.square(Dimensions.size))
    }

    private var segmentPortion: CGFloat {
        CGFloat(max(load, Dimensions.minimumVisibleLoad)) / 100
    }

    private var style: AppTheme.Style {
        if load < 76 {
            .success
        } else if load < 91 {
            .warning
        } else {
            .danger
        }
    }

    private enum Dimensions {
        static let size: CGFloat = 15
        static let ringInset: CGFloat = 2
        static let ringWidth: CGFloat = 1
        static let segmentInset: CGFloat = 2
        static let segmentWidth: CGFloat = 2
        static let minimumVisibleLoad = 15
    }
}

#if DEBUG
    #Preview {
        HStack(spacing: 8) {
            LoadCircleView(load: 5)
            LoadCircleView(load: 34)
            LoadCircleView(load: 80)
            LoadCircleView(load: 95)
        }
        .padding()
        .background(Color(.background))
    }
#endif
