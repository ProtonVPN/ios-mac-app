//
//  Created on 2026-05-12 by Pawel Jurczyk.
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

import ComposableArchitecture
import PCAPShared
import SwiftUI

struct SessionCapturedView: View {
    @Bindable var store: StoreOf<SessionCapturedFeature>

    var body: some View {
        VStack(spacing: .themeSpacing24) {
            switch store.captureSession {
            case let .sessionEnded(urlWithSize):
                SessionCapturedExportView(url: urlWithSize.url)
            default:
                EmptyView()
            }
            SessionCaptureInfoView()
            Spacer(minLength: 0)
        }
        .padding(.themeSpacing16)
        .background(Color(.background))
        .alert($store.scope(state: \.alert, action: \.alert))
    }
}
