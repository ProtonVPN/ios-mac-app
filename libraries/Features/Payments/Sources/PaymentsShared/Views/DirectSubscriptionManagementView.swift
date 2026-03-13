//
//  Created on 13/03/2026 by Max Kupetskyi.
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

#if os(iOS)
    import Combine
    import CommonNetworking
    import Dependencies
    import ProtonCorePaymentsUIV2
    import ProtonCorePaymentsV2
    import ProtonCoreServices
    import SwiftUI
    import VPNAppCore

    public struct DirectSubscriptionManagementView: View {
        @Dependency(\.networking) private var networking
        @Dependency(\.authKeychain) private var authKeychain

        @StateObject private var coordinator = Coordinator()

        public init() {}

        public var body: some View {
            Group {
                if let viewModel = coordinator.viewModel {
                    AvailablePlansView(viewModel: viewModel)
                } else {
                    Color.clear
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .task {
                coordinator.setupIfNeeded(
                    apiService: networking.apiService,
                    hideCurrentPlan: authKeychain.fetch()?.isCredentialLess != false
                )
            }
        }
    }

    @MainActor
    private final class Coordinator: ObservableObject {
        @Published var viewModel: AvailablePlansViewModel?
        private var cancellables = Set<AnyCancellable>()

        func setupIfNeeded(
            apiService: any APIService,
            hideCurrentPlan: Bool
        ) {
            guard viewModel == nil else { return }
            let viewModel = AvailablePlansViewModel(
                remoteManager: RemoteManager(apiService: apiService),
                hideCurrentPlan: hideCurrentPlan,
                presentationMode: .none
            )
            self.viewModel = viewModel
        }
    }
#endif
