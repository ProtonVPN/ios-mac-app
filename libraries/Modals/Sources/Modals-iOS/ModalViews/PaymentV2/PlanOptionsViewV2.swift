//
//  Created on 07/07/2025 by Max Kupetskyi.
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

import ModalsServices
import ModalsShared
import SwiftUI

struct PlanOptionsViewV2: View {
    private static let imagePadding: EdgeInsets = .init(top: 0, leading: 52, bottom: 24, trailing: 52)
    private static let maxContentWidth: CGFloat = 480

    typealias ActionHandler = () -> Void

    @Environment(\.dismiss) var dismiss

    @ObservedObject var viewModel: PlanOptionsListViewModelV2

    let modalType: ModalType
    let displayBodyFeatures: Bool

    let dismissAction: ActionHandler?

    init(
        viewModel: PlanOptionsListViewModelV2,
        modalType: ModalType,
        displayBodyFeatures: Bool = false,
        dismissAction: ActionHandler? = nil
    ) {
        self.modalType = modalType
        self.displayBodyFeatures = displayBodyFeatures
        self.viewModel = viewModel
        self.dismissAction = dismissAction
    }

    var body: some View {
        let modalModel = modalType.modalModel(legacy: displayBodyFeatures)
        let showSecondaryButton = displayBodyFeatures

        UpsellBackgroundView(showGradient: modalModel.shouldAddGradient) {
            VStack {
                ModalBodyView(modalType: modalType, displayBodyFeatures: displayBodyFeatures, imagePadding: imagePadding)

                Spacer()

                PlanOptionsListViewV2(viewModel: viewModel, showSecondaryButton: showSecondaryButton)
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.bottom, .themeSpacing8)
            .safeAreaInset(edge: .top) {
                if !showSecondaryButton {
                    navigationBar
                }
            }
            .frame(maxWidth: Self.maxContentWidth)
        }
        .overlay(
            purchaseInProgressView
                .transition(.opacity)
                .animation(.easeInOut, value: viewModel.isPurchaseInProgress)
        )
        .background(Color(.background))
    }

    private var navigationBar: some View {
        HStack {
            Button {
                // Prioritizes explicit dismissAction over @Environment(\.dismiss)
                if let dismissAction {
                    dismissAction()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
            }

            Spacer()
        }
        .tint(Color(.icon))
        .padding()
    }

    @ViewBuilder
    private var purchaseInProgressView: some View {
        if viewModel.isPurchaseInProgress {
            ZStack {
                Color(white: 0, opacity: 0.75)
                ProgressView()
                    .tint(.primary)
                    .controlSize(.large)
            }
            .ignoresSafeArea()
        }
    }

    private var imagePadding: EdgeInsets? {
        modalType.hasNewUpsellScreen ? Self.imagePadding : nil
    }
}

#if DEBUG
    import CombineSchedulers

    #Preview("Classic") {
        let scheduler: AnySchedulerOf<DispatchQueue> = .main
        let plans: [PlanOptionV2] = [.oneYear, .oneMonth]
        let client: PlansClientV2 = .init(
            retrievePlans: { plans },
            validate: { _ in
                try? await scheduler.sleep(for: .milliseconds((2000 ... 3000).randomElement()!))
                return .success(())
            },
            availableDiscount: { _ in 23 },
            notNow: { _ in }
        )
        PlanOptionsViewV2(viewModel: .init(client: client), modalType: .subscription)
    }

    #Preview("Loading") {
        let scheduler: AnySchedulerOf<DispatchQueue> = .main
        let plans: [PlanOptionV2] = [.oneYear, .oneMonth]
        let client: PlansClientV2 = .init(
            retrievePlans: {
                try? await scheduler.sleep(for: .milliseconds((500 ... 2000).randomElement()!))
                return plans
            },
            validate: { _ in
                try? await scheduler.sleep(for: .milliseconds((2000 ... 3000).randomElement()!))
                return .success(())
            },
            availableDiscount: { _ in 49 },
            notNow: { _ in }
        )
        PlanOptionsViewV2(viewModel: .init(client: client), modalType: .subscription)
    }
#endif
