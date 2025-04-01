//
//  Created on 25/02/2025.
//
//  Copyright (c) 2025 Proton AG
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

import HomeShared

@available(iOS 17.0, *)
struct WhatsNewViewContainer: View {
    let store: StoreOf<WhatsNewPresenterFeature>

    var body: some View {
        store.item
            .viewBody {
                store.send(.dismissItem)
            }
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
    }
}

@available(iOS 17.0, *)
private extension WhatsNew.Item {
    func viewBody(primaryAction: @escaping () -> Void) -> some View {
        switch self {
        case .widgetAdoption:
            WidgetAdoptionView(primaryAction: primaryAction)
        default:
            fatalError("Missing viewBody implementation for \(self)")
        }
    }
}
