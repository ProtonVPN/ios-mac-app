//
//  Created on 14/07/2023.
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
import Strings
import Theme
import VPNAppCore
import Home

struct RecentConnectionOptionsButton: View {
    let item: RecentConnection

    let sendAction: HomeFeature.ActionSender

    @State var isPresented = false

    static let minWidth: CGFloat = 144

    var body: some View {
        VStack {
            Button {
                self.isPresented.toggle()
            } label: {
                Asset.icThreeDotsVertical
                    .swiftUIImage
                    .resizable()
                    .frame(.square(16))
                    .padding(.themeSpacing8)
            }
            .help(Localizable.homeRecentsOptionsButtonHelp)
            .buttonStyle(RecentsButtonStyle())
            .popover(isPresented: $isPresented,
                     attachmentAnchor: .point(.bottom),
                     arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    OptionButton(role: .pin(isPinned: item.pinned)) {
                        isPresented = false
                        if item.pinned {
                            sendAction(.unpin(item.connection))
                        } else {
                            sendAction(.pin(item.connection))
                        }
                    }
                    OptionButton(role: .remove) {
                        isPresented = false
                        sendAction(.remove(item.connection))
                    }
                }
                .padding(.themeSpacing4)
                .frame(minWidth: Self.minWidth)
            }
        }
    }
}


private extension RecentConnectionOptionsButton {
    struct OptionButton: View {
        enum Role {
            case pin(isPinned: Bool)
            case remove
        }
        let role: Role
        let action: () -> Void

        var image: Theme.ImageAsset {
            switch role {
            case .pin(let isPinned):
                return (isPinned
                        ? Asset.icPinSlashFilled
                        : Asset.icPinFilled)
            case .remove:
                return Asset.icTrashCross
            }
        }
        var text: Text {
            switch role {
            case .pin(let isPinned):
                return Text(isPinned
                            ? Localizable.actionHomeUnpin
                            : Localizable.actionHomePin)
            case .remove:
                return Text(Localizable.actionRemove)
            }
        }

        var body: some View {
            Button {
                action()
            } label: {
                HStack(spacing: .themeSpacing4) {
                    image
                        .swiftUIImage
                        .resizable()
                        .frame(.square(16))
                    text
                    Spacer()
                }
                .padding(.themeSpacing4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(RecentConnectOptionsButtonStyle())
        }
    }
}

private struct RecentConnectOptionsButtonStyle: ButtonStyle {

    @State var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration
            .label
            .foregroundColor(Color(.text, isHovered ? .primary : []))
            .font(.body)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .cornerRadius(.themeRadius8)
            .onHover { isHovered = $0 }
    }

    func backgroundColor(isPressed: Bool) -> Color {
        var style: AppTheme.Style = []
        style.insert(isHovered ? .interactive : .transparent)
        return Color(.background, style)
    }
}

struct RecentConnectionOptionsButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            RecentConnectionOptionsButton(item: .connectionRegion) { _ in }
            RecentConnectionOptionsButton(item: .pinnedConnection) { _ in }
            RecentConnectionOptionsButton(item: .connectionRegion) { _ in }
            RecentConnectionOptionsButton(item: .pinnedConnection) { _ in }
        }
        .frame(.square(200))
    }
}