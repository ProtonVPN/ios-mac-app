//
//  Created on 28/01/2026 by Max Kupetskyi.
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

import Strings
import SwiftUI
import Theme

struct NoResultsContentView: View {
    var body: some View {
        VStack(spacing: .themeSpacing2) {
            Text(Localizable.searchNoResultsTitle)
                .themeFont(.headline)
                .foregroundColor(Color(.text))
                .multilineTextAlignment(.center)

            Text(Localizable.searchNoResultsSubtitle)
                .themeFont(.body1())
                .foregroundColor(Color(.text, .weak))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color(.background))
    }
}

#if DEBUG
    #Preview("No Results") {
        NoResultsContentView()
            .preferredColorScheme(.dark)
    }
#endif
