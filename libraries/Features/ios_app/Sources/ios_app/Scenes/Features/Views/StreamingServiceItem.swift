//
//  Created on 23/12/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import CommonNetworking
import Dependencies
import LegacyCommon
import SwiftUI

struct StreamingServiceItem: View {
    let service: VpnStreamingOption

    @Dependency(\.propertiesManager) private var propertiesManager
    @State private var showImage = false

    var body: some View {
        Group {
            if showImage,
               let baseUrl = propertiesManager.streamingResourcesUrl,
               let url = URL(string: baseUrl + service.icon) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure, .empty:
                        Text(service.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    @unknown default:
                        Text(service.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
            } else {
                Text(service.name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            showImage = propertiesManager.featureFlags.streamingServicesLogos
        }
    }
}

#Preview("Netflix") {
    StreamingServiceItem(
        service: .init(name: "Netflix", icon: "netflix.png")
    )
    .preferredColorScheme(.dark)
}

#Preview("Disney+") {
    StreamingServiceItem(
        service: .init(name: "Disney+", icon: "disney.png")
    )
    .preferredColorScheme(.dark)
}

#Preview("HBO Max") {
    StreamingServiceItem(
        service: .init(name: "HBO Max", icon: "hbo.png")
    )
    .preferredColorScheme(.dark)
}

#Preview("Amazon Prime Video") {
    StreamingServiceItem(
        service: .init(name: "Amazon Prime Video", icon: "amazon.png")
    )
    .preferredColorScheme(.dark)
}
