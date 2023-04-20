//
//  Created on 20/04/2023.
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

/// This view is left here only for educational/experimenting purpose
private struct BordersView: View {
    @Environment(\.pixelLength) var pixelLength: CGFloat
    var body: some View {
        ZStack {
            Color(.background, .strong)
            VStack {
                Text("Border 1 interaction-norm")
                    .frame(width: 343, height: 48)
                    .themeBorder(color: Color(.border, .interactive),
                                 lineWidth: 1,
                                 cornerRadius: .radius8)
                Text("Border 1 separator-norm")
                    .frame(width: 343, height: 48)
                    .themeBorder(color: Color(.border),
                                 lineWidth: 1,
                                 cornerRadius: .radius8)
            }
        }
    }
}


struct BordersView_Previews: PreviewProvider {
    static var previews: some View {
        BordersView()
            .previewLayout(.fixed(width: 400, height: 400))
    }
}
