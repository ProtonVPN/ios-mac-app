//
//  Created on 20/01/2026 by Max Kupetskyi.
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

import CommonNetworking
import ComposableArchitecture
import Foundation

@Reducer
struct StreamingServiceItem {
    @ObservableState
    struct State: Equatable, Identifiable {
        let service: VpnStreamingOption
        var showImage: Bool

        var id: String { service.name }

        var imageURL: URL? {
            @Dependency(\.propertiesManager) var propertiesManager
            guard let baseUrl = propertiesManager.streamingResourcesUrl,
                  let url = URL(string: baseUrl + service.icon) else { return nil }
            return url
        }
    }

    enum Action {
        case onAppear
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .onAppear:
                .none
            }
        }
    }
}
