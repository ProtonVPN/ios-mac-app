//
//  Created on 27/03/2026 by Max Kupetskyi.
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

import AppKit
import Countries
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Modals
import NetShield
import Strings
import SwiftUI
import Theme
import VPNShared

final class CountriesSectionViewController: NSHostingController<CountriesSectionRootView> {
    private let screenViewModel: CountriesSectionScreenViewModel
    private var appliedWindowExtraHeight: CGFloat = 0
    private var pendingWindowExtraHeight: CGFloat = 0
    private var resizeWorkItem: DispatchWorkItem?

    required init(viewModel: CountriesSectionViewModel) {
        let screenViewModel = CountriesSectionScreenViewModel(viewModel: viewModel)
        self.screenViewModel = screenViewModel
        super.init(rootView: CountriesSectionRootView(viewModel: screenViewModel))
        screenViewModel.presentSheet = { [weak self] controller in
            self?.presentAsSheet(controller)
        }
        screenViewModel.onRequiredExtraHeightChanged = { [weak self] requiredHeight in
            self?.applyRequiredWindowExtraHeight(requiredHeight)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        super.loadView()
        // The sidebar embeds child controller views with Auto Layout constraints.
        // Prevent NSHostingView from generating autoresizing-mask constraints.
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        screenViewModel.quickSettingsManager.hideAllSettings()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyRequiredWindowExtraHeight(pendingWindowExtraHeight)
    }

    private func applyRequiredWindowExtraHeight(_ requiredHeight: CGFloat) {
        pendingWindowExtraHeight = max(0, requiredHeight)
        resizeWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let window = view.window,
                  !window.styleMask.contains(.fullScreen) else { return }

            // Monotonic growth: never shrink back automatically.
            guard pendingWindowExtraHeight > appliedWindowExtraHeight else { return }

            // Keep growth within visible screen bounds.
            let baselineHeight = window.frame.height - appliedWindowExtraHeight
            let maxExtraHeight: CGFloat = if let visibleFrameHeight = window.screen?.visibleFrame.height {
                max(0, visibleFrameHeight - baselineHeight)
            } else {
                pendingWindowExtraHeight
            }
            let targetExtra = min(pendingWindowExtraHeight, maxExtraHeight)
            guard targetExtra > appliedWindowExtraHeight else { return }

            let delta = targetExtra - appliedWindowExtraHeight
            var frame = window.frame
            frame.origin.y -= delta
            frame.size.height += delta
            // Apply without animation to avoid intermediate layout jitter.
            window.setFrame(frame, display: true, animate: false)
            appliedWindowExtraHeight = targetExtra
        }

        resizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }
}

@MainActor
final class CountriesSectionScreenViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published private(set) var netShieldBadgeText = "0"
    @Published private(set) var netShieldBadgeVisible = false
    @Published private(set) var netShieldBadgeEnabled = false

    let viewModel: CountriesSectionViewModel
    let quickSettingsManager = QuickSettingsManager()
    var presentSheet: ((NSViewController) -> Void)?
    var onRequiredExtraHeightChanged: ((CGFloat) -> Void)?

    private var notificationTokens: [NotificationToken] = []
    private var netShieldObserverTask: Task<Void, Never>?
    private var requiredExtraHeight: CGFloat = 0
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    init(viewModel: CountriesSectionViewModel) {
        self.viewModel = viewModel
        setupViewModelCallbacks()
        setupQuickSettings()
        setupNetShieldObservers()
        updateNetShieldBadge()
        updatePortForwardingView()
    }

    deinit {
        netShieldObserverTask?.cancel()
    }

    var isSearchDisabled: Bool { quickSettingsManager.activeType != nil }
    var activeConfiguration: QuickSettingConfiguration? { quickSettingsManager.activeConfiguration }
    var visibleQuickSettingTypes: [QuickSettingType] { QuickSettingType.allCases.filter { quickSettingsManager.isVisible($0) } }

    func didTapQuickSetting(_ type: QuickSettingType) {
        quickSettingsManager.handleButtonTap(for: type)
    }

    func clearSearch() {
        guard !searchQuery.isEmpty else { return }
        searchQuery = ""
        viewModel.filterContent(forQuery: "")
    }

    func onSearchChanged(_ value: String) {
        viewModel.filterContent(forQuery: value)
    }

    func updateRequiredWindowExtra(detailHeight: CGFloat, availableHeight: CGFloat) {
        let required = max(0, detailHeight - availableHeight)
        guard abs(required - requiredExtraHeight) > 0.5 else { return }
        requiredExtraHeight = required
        onRequiredExtraHeightChanged?(required)
    }

    func resetRequiredWindowExtra() {
        guard requiredExtraHeight != 0 else { return }
        requiredExtraHeight = 0
        onRequiredExtraHeightChanged?(0)
    }

    func updatePortForwardingView() {
        guard VPNFeatureFlagType.portForwarding.enabled else { return }
        @Dependency(\.natPortMappingService) var natPortMappingService
        if case .failure = natPortMappingService.portMappingStream.value {
            quickSettingsManager.updateState(connectionInfo: .pfError(isConnected: viewModel.isConnected))
            return
        }
        quickSettingsManager.updateState(connectionInfo: .connected(
            portForwardingEnabled: viewModel.portForwardingIsOn,
            supportsP2P: viewModel.connectedServerSupportsP2P,
            isConnected: viewModel.isConnected
        ))
    }

    private func setupQuickSettings() {
        quickSettingsManager.setup(with: viewModel)
        quickSettingsManager.onDidShowSetting = { [weak self] _ in self?.objectWillChange.send() }
        quickSettingsManager.onDidHideAllSettings = { [weak self] in self?.objectWillChange.send() }
    }

    private func setupViewModelCallbacks() {
        viewModel.contentChanged = { [weak self] _ in self?.updatePortForwardingView() }
        viewModel.displayPremiumServices = { [weak self] in
            self?.presentSheet?(FeaturesOverlayViewController(viewModel: PremiumFeaturesOverlayViewModel()))
        }
        viewModel.displayStreamingServices = { [weak self] country, services in
            self?.presentSheet?(StreamingServicesOverlayViewController(
                viewModel: StreamingServicesOverlayViewModel(country: country, streamServices: services)
            ))
        }
        viewModel.displayGatewaysServices = { [weak self] in
            self?.presentSheet?(FeaturesOverlayViewController(viewModel: GatewayFeaturesOverlayViewModel()))
        }
    }

    private func setupNetShieldObservers() {
        notificationTokens.append(NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self, object: nil) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateNetShieldBadge()
            }
        })

        netShieldObserverTask = Task { [weak self] in
            guard let self else { return }
            for await _ in netShieldPropertyProvider.netShieldTypeStream() {
                try? Task.checkCancellation()
                await MainActor.run { self.updateNetShieldBadge() }
            }
        }
    }

    private func updateNetShieldBadge() {
        guard let presenter = quickSettingsManager.configurations[.netShieldDisplay]?.presenter as? NetshieldDropdownPresenter else {
            netShieldBadgeVisible = false
            return
        }
        guard presenter.isNetShieldStatsEnabled else {
            netShieldBadgeVisible = false
            return
        }

        netShieldBadgeVisible = presenter.appStateManager.displayState == .connected
        var stats = presenter.netShieldStats
        if presenter.netShieldPropertyProvider.getNetShieldType() != .level2 {
            stats = .zero(enabled: false)
        }
        netShieldBadgeEnabled = stats.enabled
        let count = stats.adsCount + stats.trackersCount
        netShieldBadgeText = count >= 99 ? "99+" : "\(count)"
    }
}

struct CountriesSectionRootView: View {
    @ObservedObject var viewModel: CountriesSectionScreenViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    quickSettingsRow
                    searchBar.padding(.horizontal, .themeSpacing20).padding(.top, .themeSpacing8)
                    CountriesListView(store: viewModel.viewModel.store).padding(.top, .themeSpacing8)
                }
                .background(Color(.background, .weak))

                if let configuration = viewModel.activeConfiguration {
                    QuickSettingDetailView(
                        manager: viewModel.quickSettingsManager,
                        configuration: configuration,
                        visibleQuickSettingTypes: viewModel.visibleQuickSettingTypes,
                        availableWidth: proxy.size.width
                    )
                    .background(GeometryReader { detailProxy in
                        Color.clear.preference(key: QuickSettingDetailHeightPreferenceKey.self, value: detailProxy.size.height)
                    })
                    .padding(.top, Dimensions.quickSettingsDetailTopPadding)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .onPreferenceChange(QuickSettingDetailHeightPreferenceKey.self) { detailHeight in
                let availableHeight = max(proxy.size.height - Dimensions.quickSettingsDetailTopPadding, 0)
                viewModel.updateRequiredWindowExtra(detailHeight: detailHeight, availableHeight: availableHeight)
            }
            .onChange(of: viewModel.activeConfiguration?.type) { _, activeType in
                if activeType == nil {
                    viewModel.resetRequiredWindowExtra()
                }
            }
        }
    }

    private var quickSettingsRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.visibleQuickSettingTypes, id: \.self) { type in
                ZStack(alignment: .topTrailing) {
                    QuickSettingButtonView(
                        icon: viewModel.quickSettingsManager.buttonIcon(for: type),
                        isEnabled: viewModel.quickSettingsManager.isEnabled(type),
                        toolTip: viewModel.quickSettingsManager.buttonTooltip(for: type),
                        accessibilityIdentifier: accessibilityIdentifier(for: type),
                        action: { viewModel.didTapQuickSetting(type) }
                    )
                    .padding(.horizontal, .themeSpacing8)
                    .padding(.top, .themeSpacing4)
                    .padding(.bottom, .themeSpacing12)

                    if type == .netShieldDisplay, viewModel.netShieldBadgeVisible {
                        Text(viewModel.netShieldBadgeText)
                            .themeFont(.footnote(emphasised: true))
                            .foregroundStyle(viewModel.netShieldBadgeEnabled ? .white : Color(.text, .hint))
                            .padding(.horizontal, .themeSpacing6)
                            .frame(minWidth: Dimensions.quickSettingsBadgeMinWidth, minHeight: Dimensions.quickSettingsBadgeMinHeight)
                            .background(RoundedRectangle(cornerRadius: Dimensions.quickSettingsBadgeCornerRadius).fill(Color(.background)))
                            .offset(x: Dimensions.quickSettingsBadgeOffsetX, y: Dimensions.quickSettingsBadgeOffsetY)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Dimensions.quickSettingsRowHeight, maxHeight: Dimensions.quickSettingsRowHeight)
            }
        }
        .frame(height: Dimensions.quickSettingsRowHeight)
        .padding(.horizontal, .themeSpacing12)
        .padding(.top, .themeSpacing8)
        .accessibilityLabel(Localizable.quickSettingsTitle)
    }

    private var searchBar: some View {
        HStack(spacing: .themeSpacing8) {
            Theme.Asset.Icons.magnifier.swiftUIImage
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color(.icon, .hint))
                .frame(.square(Dimensions.iconSize))

            TextField(Localizable.searchForCountry, text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.title3(emphasised: false))
                .disabled(viewModel.isSearchDisabled)
                .onChange(of: viewModel.searchQuery) { _, newValue in viewModel.onSearchChanged(newValue) }
                .accessibilityIdentifier("SearchTextField")

            if !viewModel.searchQuery.isEmpty {
                Button(action: viewModel.clearSearch) {
                    Theme.Asset.Icons.crossCircleFilled.swiftUIImage
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(Color(.icon, .hint))
                        .frame(.square(Dimensions.iconSize))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ClearSearchButton")
            }
        }
        .padding(.horizontal, .themeSpacing8)
        .frame(height: Dimensions.searchBarHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                .fill(Color(.background, .weak))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                        .stroke(Color(.border), lineWidth: Dimensions.searchBarBorderWidth)
                )
        )
    }

    private func accessibilityIdentifier(for type: QuickSettingType) -> String {
        switch type {
        case .secureCoreDisplay: "SecureCoreButton"
        case .netShieldDisplay: "NetShieldButton"
        case .killSwitchDisplay: "KillSwitchButton"
        case .portForwardingDisplay: "PortForwardingButton"
        }
    }
}

private extension CountriesSectionRootView {
    enum Dimensions {
        static let iconSize: CGFloat = 16

        static let quickSettingsRowHeight: CGFloat = 54
        static let quickSettingsBadgeMinWidth: CGFloat = 20
        static let quickSettingsBadgeMinHeight: CGFloat = 14
        static let quickSettingsBadgeCornerRadius: CGFloat = 4
        static let quickSettingsBadgeOffsetX: CGFloat = -20
        static let quickSettingsBadgeOffsetY: CGFloat = 6
        static let quickSettingsDetailTopPadding: CGFloat = 48

        static let searchBarHeight: CGFloat = 46
        static let searchBarBorderWidth: CGFloat = 1
    }
}

private struct QuickSettingDetailHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
