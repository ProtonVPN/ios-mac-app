//
//  Created on 15/10/2024.
//
//  Copyright (c) 2024 Proton AG
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

import Domain
import Strings

struct RecentConnectionActionsView: View {
    let intent: ConnectionSpec
    let isPinned: Bool
    let images: RecentsImages
    let detailAction: (ConnectionFlagInfoView.Action) -> Void

    private struct ButtonModel {
        let action: ConnectionFlagInfoView.Action
        let image: Image
        let text: String
    }

    private var pinModel: ButtonModel {
        .init(action: .pin,
              image: images.pinFilled,
              text: Localizable.actionHomePin)
    }

    private var unpinModel: ButtonModel {
        .init(action: .unpin,
              image: images.pinSlashFilled,
              text: Localizable.actionHomeUnpin)
    }

    private var removeModel: ButtonModel {
        .init(action: .remove,
              image: images.trashCrossFilled,
              text: Localizable.actionRemove)
    }

    private var flagInfoView: some View {
        ConnectionFlagInfoView(
            intent: intent,
            underMaintenance: false,
            isPinned: false,
            vpnConnectionActual: nil,
            withDivider: false,
            images: images,
            detailAction: nil
        )
        .listRowBackground(Color(.background))
    }

    private func button(model: ButtonModel) -> some View {
        Button {
            detailAction(model.action)
        } label: {
            HStack(spacing: .themeSpacing12) {
                model
                    .image
                    .frame(width: 30)
                Text(model.text)
            }
        }
        .listRowBackground(Color(.background))
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Color(.background)
                    .frame(height: 20)
            }
            #endif
            List {
                flagInfoView
                button(model: isPinned ? unpinModel : pinModel)
                button(model: removeModel)
            }
            .environment(\.defaultMinListRowHeight, 64)
            .listStyle(PlainListStyle())
            .background(Color(.background))
        }
        .frame(minWidth: 250, minHeight: 64 * 3)
    }
}
