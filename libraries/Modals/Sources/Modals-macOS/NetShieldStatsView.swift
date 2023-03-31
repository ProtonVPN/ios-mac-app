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

import SwiftUI

@available(macOS 11.0, *)
public struct NetShieldStatsView: View {

    @ObservedObject public var viewModel: NetShieldStatsViewModel

    public var body: some View {
        HStack(spacing: 0) {
            StatsView(model: viewModel.adsStats)
            StatsView(model: viewModel.trackersStats)
            StatsView(model: viewModel.dataStats)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color(colors.backgroundWeak)))
    }
    public init(viewModel: NetShieldStatsViewModel) {
        self.viewModel = viewModel
    }
}

@available(macOS 11.0, *)
struct StatsView: View {
    @State var isHovered = false

    var statsViewHeight: CGFloat = 56
    var statsViewWidth: CGFloat = 80

    let model: NetShieldStatsViewModel.NetShieldStat

    public var body: some View {
        VStack(alignment: .center) {
            Text(model.value)
                .foregroundColor(valueForegroundColor())
                .font(.system(size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(model.title)
                .foregroundColor(titleForegroundColor())
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
        }
        .frame(width: statsViewWidth, height: statsViewHeight)
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(backgroundColor())
        )
        .help(model.help)
    }

    func valueForegroundColor() -> Color {
        model.isDisabled ? Color(colors.textHint) : .white
    }

    func titleForegroundColor() -> Color {
        Color(model.isDisabled ? colors.textHint : colors.weakText)
    }

    func backgroundColor() -> Color {
        isHovered ? Color(colors.backgroundHover) : .clear
    }
}

@available(macOS 11.0, *)
struct NetShieldStatsView_Previews: PreviewProvider {
    static var previews: some View {
        NetShieldStatsView(viewModel: .previewModel)
            .previewLayout(.sizeThatFits)
    }
}

private extension NetShieldStatsViewModel {
    static var previewModel: NetShieldStatsViewModel = {
        .init(adsStatsTitle: "Ads\nblocked",
              trackersStatsTitle: "Trackers\nstopped",
              dataStatsTitle: "Data\nsaved")
    }()
}
