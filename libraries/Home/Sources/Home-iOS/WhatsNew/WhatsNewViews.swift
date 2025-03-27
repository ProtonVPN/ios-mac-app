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

import Home

@available(iOS 17.0, *)
struct WhatsNewViewContainer: View {
    fileprivate struct Context {
        private(set) var detents: Set<PresentationDetent> = [.height(.zero), .large]
        var selectedDetent: PresentationDetent = .height(.zero) {
            didSet {
                if selectedDetent != .large {
                    detents = [selectedDetent, .large]
                }
            }
        }
    }

    let store: StoreOf<WhatsNewPresenterFeature>

    @State private var context = Context()

    var body: some View {
        store.item
            .viewBody(with: $context) {
                store.send(.dismissItem)
            }
            .presentationDragIndicator(.visible)
            .presentationDetents(context.detents, selection: $context.selectedDetent)
    }
}

@available(iOS 17.0, *)
private extension WhatsNew.Item {
    func viewBody(with context: Binding<WhatsNewViewContainer.Context>, primaryAction: @escaping () -> Void) -> some View {
        switch self {
        case .widgetAdoption:
            WidgetAdoptionView(selectedDetent: context.selectedDetent, primaryAction: primaryAction)
        default:
            fatalError("Missing viewBody implementation for \(self)")
        }
    }
}
