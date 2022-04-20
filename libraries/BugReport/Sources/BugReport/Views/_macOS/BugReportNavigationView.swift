//
//  Created on 2022-01-24.
//
//  Copyright (c) 2022 Proton AG
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

#if os(macOS)
import SwiftUI

extension AnyTransition {

    /// Transition that adds views like in the navigationView.
    public static let navigationalPush: AnyTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .opacity
    )

    /// Transition that adds views like in the navigationView.
    public static let navigationalPop: AnyTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .leading),
        removal: .opacity
    )
}

/// Makes navigation through bug report on mac similar to iOS NavogationView.
@available(macOS 11, *)
struct BugReportNavigationView: View {

    @StateObject var viewModel: MacBugReportViewModel

    @Environment(\.colors) var colors: Colors

    private let verticalPadding = 64.0
    private let horizontalPadding = 126.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if case .result(let error) = viewModel.page {
                ResultView(
                    error: error,
                    finishCallback: { viewModel.form?.finished() },
                    retryCallback: { withAnimation { self.viewModel.back() } },
                    troubleshootCallback: { viewModel.form?.troubleshootingTapped() }
                )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, verticalPadding)

            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Button("", action: { withAnimation { self.viewModel.back() } })
                        .buttonStyle(BackButtonStyle())
                        .opacity(viewModel.step > 1 ? 1 : 0) // There is no hidden() modifier with condition, so here we go :(
                        .transition(.opacity)

                    StepProgress(step: viewModel.step, steps: viewModel.steps, colorMain: colors.primary, colorText: colors.textAccent, colorSecondary: colors.backgroundStrong ?? colors.backgroundWeak)
                        .padding(.bottom)
                        .transition(.opacity)

                    UpdateAvailableView(isActive: $viewModel.updateIsAvailable)
                }
                .padding(.horizontal, horizontalPadding)

                ScrollView {
                    Group {
                        switch viewModel.page {
                        case .categories(let categories):
                            BugReportMacOSView(categories: categories, categorySelected: { category in
                                withAnimation {
                                    viewModel.categorySelected(category)
                                }
                            })
                                .transition(viewModel.navigationType == .pop ? .navigationalPop : .navigationalPush)

                        case .suggestions(let category):
                            QuickFixesMacOSList(category: category, finished: { withAnimation { viewModel.suggestionsFinished() } })
                                .transition(viewModel.navigationType == .pop ? .navigationalPop : .navigationalPush)

                        case .form(let formViewModel):
                            FormMacOSView(viewModel: formViewModel)
                                .transition(viewModel.navigationType == .pop ? .navigationalPop : .navigationalPush)

                        case .result(let error):
                            ResultView(
                                error: error,
                                finishCallback: { viewModel.form?.finished() },
                                retryCallback: { withAnimation { self.viewModel.back() } },
                                troubleshootCallback: { viewModel.form?.troubleshootingTapped() }
                            )
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, verticalPadding)
                }

            }
        }
        .padding(.top, verticalPadding)
        .background(colors.background)
    }
}

// MARK: - Preview

@available(macOS 11, *)
struct BugReportNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                BugReportNavigationView(viewModel: MacBugReportViewModel(model: .mock))
            }
            VStack {
                BugReportNavigationView(viewModel: step2)
            }
            VStack {
                BugReportNavigationView(viewModel: step3)
            }
            VStack {
                BugReportNavigationView(viewModel: stepResult)
            }
        }
        .preferredColorScheme(.dark)
    }

    private static var step2: MacBugReportViewModel {
        let step2 = MacBugReportViewModel(model: .mock)
        step2.categorySelected(BugReportModel.mock.categories.first!)
        return step2
    }

    private static var step3: MacBugReportViewModel {
        let step3 = MacBugReportViewModel(model: .mock)
        step3.categorySelected(BugReportModel.mock.categories.first!)
        step3.suggestionsFinished()
        return step3
    }

    private static var stepResult: MacBugReportViewModel {
        let step = MacBugReportViewModel(model: .mock)
        step.categorySelected(BugReportModel.mock.categories.first!)
        step.suggestionsFinished()
        step.form?.sendResult = .success(Void())
        step.resultReceived()
        return step
    }

}

#endif
