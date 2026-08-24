//
//  Created on 11/08/2026 by Max Kupetskyi.
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

import Dependencies
import Ergonomics
import Strings
import SwiftUI
import Theme

/// Quick Connect while disconnected, Disconnect while connected.
struct HeaderConnectButton: View {
    let kind: HeaderFeature.State.ConnectButtonKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(kind == .disconnect ? Localizable.disconnect : Localizable.quickConnect)
                .themeFont(.title2())
                .foregroundStyle(Color(.text))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(kind == .disconnect ? HeaderButtonStyle.destructive : .interactive)
    }
}

/// Lets a free user move to another server, with the wait until they may do so again.
///
/// The countdown redraws itself once a second through `TimelineView`, so the reducer does not tick.
struct HeaderChangeServerButton: View {
    let allowedDate: Date?
    let action: () -> Void

    @Dependency(\.date) private var date

    var body: some View {
        TimelineView(.explicit(updateSchedule)) { _ in
            Button(action: action) {
                if let allowedDate, allowedDate > date.now {
                    waiting(until: allowedDate)
                } else {
                    Text(Localizable.changeServer)
                        .themeFont(.title2())
                        .foregroundStyle(Color(.text))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(HeaderButtonStyle.outlined)
            .disabled(isWaiting)
        }
    }

    private var isWaiting: Bool {
        guard let allowedDate else { return false }
        return allowedDate > date.now
    }

    /// The button redraws every second until two seconds past the deadline, which leaves one draw
    /// showing 0:00 and one more showing the button ready again.
    private var updateSchedule: DateSequence {
        DateSequence(end: (allowedDate ?? date.now).addingTimeInterval(2), step: 1)
    }

    private func waiting(until allowedDate: Date) -> some View {
        HStack(spacing: Dimensions.hourglassSpacing) {
            Text(Localizable.changeServer)
                .themeFont(.title2())
                .foregroundStyle(Color(.text, .weak))

            Spacer(minLength: Dimensions.hourglassSpacing)

            Theme.Asset.Icons.hourglass.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color(.text))
                .frame(.square(Dimensions.hourglassSize))

            Text(allowedDate.timeIntervalSince(date.now).asColonSeparatedString(maxUnit: .hour, minUnit: .minute))
                .themeFont(.title2())
                .foregroundStyle(Color(.text))
        }
        .padding(.horizontal, Dimensions.horizontalInset)
    }

    private enum Dimensions {
        static let horizontalInset: CGFloat = 24
        static let hourglassSize: CGFloat = 16
        static let hourglassSpacing: CGFloat = 8
    }
}

struct HeaderButtonStyle: ButtonStyle {
    /// Background style at rest.
    let resting: AppTheme.Style
    /// Background style while the pointer is over the button.
    let hovered: AppTheme.Style

    /// Filled purple at rest, brighter under the pointer. Quick Connect and Change Server on hover.
    static let interactive = HeaderButtonStyle(resting: .interactive, hovered: [.interactive, .hovered])
    /// Only an outline at rest, red under the pointer. Disconnect.
    static let destructive = HeaderButtonStyle(resting: .transparent, hovered: [.danger, .hovered])
    /// Only an outline at rest, purple under the pointer. Change Server.
    static let outlined = HeaderButtonStyle(resting: .transparent, hovered: [.interactive, .hovered])

    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(height: Dimensions.height)
            .background(Color(.background, isHovered ? hovered : resting))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                    .stroke(Color(.border, isHovered ? .transparent : .normal), lineWidth: Dimensions.borderWidth)
            }
            .clipShape(.rect(cornerRadius: AppTheme.ButtonConstants.cornerRadius))
            .opacity(configuration.isPressed ? Dimensions.pressedOpacity : 1)
            .linkPointer()
            .onHover { isHovered = $0 }
    }

    private enum Dimensions {
        static let height: CGFloat = 40
        static let borderWidth: CGFloat = 2
        static let pressedOpacity: CGFloat = 0.8
    }
}
