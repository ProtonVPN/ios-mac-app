//
//  Created on 23/03/2023.
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

import Home
import SwiftUI
import Theme
import Theme_iOS

public struct NetShieldStatsView: View {

    public var viewModel: NetShieldModel

    public var body: some View {
        HStack(spacing: 0) {
            StatsView(model: viewModel.ads)
            StatsView(model: viewModel.trackers)
            StatsView(model: viewModel.data)
        }
        .padding(8)
    }
    public init(viewModel: NetShieldModel) {
        self.viewModel = viewModel
    }
}

struct NetShieldStatsView_Previews: PreviewProvider {
    static var previews: some View {
        NetShieldStatsView(viewModel: .previewModel)
            .background(RoundedRectangle(cornerRadius: .themeRadius8)
                .fill(Color(.background, .weak)))
            .background(Color(.background))
            .previewLayout(.sizeThatFits)
    }
}

private extension NetShieldModel {
    static var previewModel: NetShieldModel = {
        .init(trackers: .init(value: "23",
                              title: "Trackers\nstopped",
                              // help: "Some help",
                              isEnabled: false),
              ads: .init(value: "12",
                         title: "Ads\nblocked",
                         // help: "Some help",
                         isEnabled: true),
              data: .init(value: "45.5 MB",
                          title: "Data\nsaved",
//                          help: "Some help",
                          isEnabled: false))
    }()
}
