//
//  Created on 2026-04-28 by Pawel Jurczyk.
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
import Connection
import Domain
import PCAPShared
import ProtonCoreUIFoundations
import Sharing
import Strings
import SwiftUI
import Theme

public struct CaptureVPNSessionView: View {
    @Bindable private var store: StoreOf<CaptureVPNSessionFeature>

    public init(store: StoreOf<CaptureVPNSessionFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            Color(.background)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                contentView()
                    .layoutPriority(1)
                Spacer()
                    .frame(height: .themeSpacing24)
                SessionCaptureInfoView()
                    .layoutPriority(1)
                VStack(spacing: 0) {
                    Spacer(minLength: .themeSpacing16)
                    Button(store.buttonText) {
                        store.send(.captureButtonPressed)
                    }
                    .buttonStyle(ThemeButtonStyle(padding: .medium, style: buttonStyle, maxWidth: .infinity))
                }
            }
            .padding(.themeSpacing16)
            .frame(maxWidth: Constants.maxHomeContentWidth)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(
            state: \.destination?.sessionCaptured,
            action: \.destination.sessionCaptured
        ), content: SessionCapturedSheetView.init(store:))
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    private var buttonStyle: ThemeButtonStyle.Style {
        switch store.captureSession {
        case .noSession, .sessionEnded:
            .primary
        default:
            .secondary
        }
    }

    @ViewBuilder
    private func contentView() -> some View {
        switch store.captureSession {
        case .noSession, .sessionEnded:
            emptyCaptureSession()
        case let .sessionStarted(urlWithData):
            capturingView(startTime: urlWithData.date)
        }
    }

    private var maxDuration: String = Duration.minutes(DomainConstants.LogFiles.pcapMaxDurationInMinutes)
        .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))

    private func capturingView(startTime: Date) -> some View {
        VStack(spacing: .themeSpacing24) {
            Spacer()
            Text(Localizable.pcapCaptureSessionCapturing)
                .themeFont(.body1(.bold))
                .foregroundStyle(Color(.text))

            VStack(spacing: .themeSpacing16) {
                HStack(spacing: .themeSpacing8) {
                    RecordingPin()
                    TimelineView(.periodic(from: startTime, by: 1)) { context in
                        let currentDuration = Duration.seconds(context.date.timeIntervalSince(startTime))
                            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
                        Text(Localizable.pcapCaptureSessionDuration(currentDuration, maxDuration))
                            .themeFont(.body2(emphasised: true))
                            .foregroundStyle(Color(.text, .danger))
                            .padding(.trailing, .themeSpacing8) // to visually center the HStack
                    }
                }
                Text(Localizable.pcapCaptureSessionDirections)
                    .themeFont(.body2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Theme.Asset.pcapCapturingBackground.swiftUIColor,
            in: RoundedRectangle(cornerRadius: .themeRadius12)
        )
    }

    private func emptyCaptureSession() -> some View {
        VStack(alignment: .leading, spacing: .themeSpacing24) {
            Image(.troubleshootingFile)
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(Localizable.createTroubleshootingFile)
                    .themeFont(.headline)

                Text(Localizable.pcapCaptureFeatureDescription)
                    .themeFont(.body2(emphasised: false))
                    .foregroundStyle(Color(.text, .weak))
            }
        }
    }
}

#Preview("no session") {
    CaptureVPNSessionView(store: .init(
        initialState: CaptureVPNSessionFeature.State(captureSession: .noSession),
        reducer: EmptyReducer.init
    ))
    .colorScheme(.dark)
}

#Preview("capture started") {
    CaptureVPNSessionView(store: .init(
        initialState: CaptureVPNSessionFeature.State(captureSession: .sessionStarted(urlWithDate: .init(url: .init(string: "file")!, date: .now))),

        reducer: EmptyReducer.init
    ))
    .colorScheme(.dark)
}
