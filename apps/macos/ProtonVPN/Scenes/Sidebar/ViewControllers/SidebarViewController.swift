//
//  SidebarViewController.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Cocoa
import ComposableArchitecture
import Dependencies

import Announcement
import Domain
import LegacyCommon
import Strings
import Theme
import VPNShared

final class SidebarViewController: NSViewController, NSWindowDelegate {
    static let reconnectionNotificationName = Notification.Name("SidebarViewControllerReconnect")

    private let allThings = NSView(frame: .zero)
    private let headerControllerViewContainer = NSView(frame: .zero)
    private let tabBarControllerViewContainer = NSView(frame: .zero)
    private let activeControllerViewContainer = NSView(frame: .zero)
    private let announcementsControllerViewContainer = NSView(frame: .zero)
    private let connectionOverlay = ConnectionOverlay(frame: .zero)
    private let sidebarContainerView = NSView(frame: .zero)
    private let mapSectionViewContainer = NSView(frame: .zero)
    private let expandButton = ExpandMapButton(frame: .zero)
    private var expandButtonLeading: NSLayoutConstraint!

    private var headerViewController: HeaderViewController!
    private var activeController: NSViewController!

    private var overlayWindowController: ConnectingWindowController?
    private var fadeOutOverlayTask: DispatchWorkItem?
    private var loading = false
    private var overlayViewModel: ConnectingOverlayViewModel?
    private var renderedLoadingOverlayVisible: Bool?
    // Retain header view model to set `changeServerStateUpdated` when needed
    private var headerViewModel: HeaderViewModel?

    typealias Factory = AnnouncementsViewModelFactory
        & ConnectingOverlayViewModelFactory
        & CoreAlertServiceFactory
        & HeaderViewModelFactory
        & MapSectionViewModelFactory
        & ProfileManagerFactory
        & SystemExtensionManagerFactory
        & VpnManagerFactory

    private let appStateManager: AppStateManager
    private let vpnGateway: VpnGatewayProtocol
    private let navService: NavigationService
    private let factory: Factory
    private let store: StoreOf<SidebarFeature>

    private lazy var tabBarViewController: SidebarTabBarViewController = .init()

    private lazy var countriesSectionViewController: CountriesSectionViewController = { [unowned self] in
        CountriesSectionViewController(
            store: store.scope(
                state: \.countriesSection,
                action: \.countriesSection
            )
        )
    }()

    private lazy var profileSectionViewController: ProfileSectionViewController = { [unowned self] in
        let viewModel = ProfilesSectionViewModel(
            vpnGateway: vpnGateway,
            navService: navService,
            alertService: factory.makeCoreAlertService(),
            profileManager: factory.makeProfileManager(),
            sysexManager: factory.makeSystemExtensionManager()
        )
        return ProfileSectionViewController(viewModel: viewModel)
    }()

    private lazy var mapHeaderViewModel: MapHeaderViewModel = { [unowned self] in
        return MapHeaderViewModel(vpnGateway: vpnGateway, appStateManager: appStateManager)
    }()

    private lazy var mapSectionViewModel: MapSectionViewModel = factory.makeMapSectionViewModel()

    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()
    private lazy var mapSectionViewController: MapSectionViewController = { [unowned self] in
        MapSectionViewController(
            mapSectionViewModel: mapSectionViewModel,
            mapHeaderViewModel: mapHeaderViewModel
        )
    }()

    // MARK: - Init

    init(
        appStateManager: AppStateManager,
        vpnGateway: VpnGatewayProtocol,
        navService: NavigationService,
        factory: Factory
    ) {
        let quickSettingsHandler = CountriesSectionQuickSettingsHandler(
            appStateManager: appStateManager,
            vpnGateway: vpnGateway,
            vpnManager: factory.makeVpnManager()
        )
        @Dependency(\.defaultsProvider) var defaultsProvider
        let store = Store(initialState: .init()) {
            SidebarFeature(
                quickSettingsEnvironment: .init(
                    performOptionSelection: { type, option, dismiss in
                        quickSettingsHandler.quickSettingsSelectOption(
                            type: type,
                            option: option,
                            dismiss: dismiss
                        )
                    },
                    initialNetShieldStats: {
                        quickSettingsHandler.quickSettingsInitialNetShieldStats
                    }
                ),
                environment: .init(
                    persistMapWidth: { mapWidth in
                        defaultsProvider.getDefaults().set(mapWidth, forKey: AppConstants.UserDefaults.mapWidth)
                    },
                ),
                sidebarWidth: Dimensions.sidebarWidth,
                expandButtonWidth: Dimensions.expandButtonWidth
            )
        }

        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.navService = navService
        self.factory = factory
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: Dimensions.sidebarWidth, height: Dimensions.initialViewHeight))
        rootView.translatesAutoresizingMaskIntoConstraints = false
        view = rootView
        buildViewHierarchy(in: rootView)
        setupLayoutConstraints(in: rootView)
    }

    // MARK: Functions

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMainView()
        setupHeader()
        setupTabBar()
        setupMapSection()

        store.send(.viewDidLoad)
        observe { [weak self] in
            guard let self else { return }
            applySidebarState()
            applyLoadingOverlayState()
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        store.send(.viewDidAppear)
        view.window?.applySidebarAppearance()
        if let window = view.window {
            store.send(.windowDidResize(width: window.frame.width))
        }

        if let overlayViewModel, !appStateManager.state.isConnected {
            showLoadingOverlay(with: overlayViewModel)
        } else {
            overlayViewModel = nil
        }
        vpnGateway.postConnectionInformation()
    }

    override func mouseDown(with _: NSEvent) {
        store.send(.mouseDown)
        view.window?.makeFirstResponder(nil)
    }

    // MARK: - Private

    private func showLoadingOverlay(with viewModel: ConnectingOverlayViewModel) {
        guard let window = view.window else { return }

        if let overlayWindow = overlayWindowController?.window, let childWindows = window.childWindows {
            if childWindows.contains(overlayWindow) {
                return // window is already displayed
            }
        }

        let connectingViewController = ConnectingViewController(viewModel: viewModel)
        overlayWindowController = ConnectingWindowController(viewController: connectingViewController)

        connectionOverlay.isHidden = false
        window.addChildWindow(overlayWindowController!.window!, ordered: .above)
        resizeOverlayWindow()
        overlayWindowController!.window!.makeKey()
    }

    private func loading(show: Bool, animateClose _: Bool = false) {
        guard let window = view.window else { return }

        loading = show

        if show {
            removeConnectingOverlay()
            let cancellation: (() -> Void) = { [weak self] in
                guard let self else {
                    return
                }

                removeConnectingOverlay()
            }

            overlayViewModel = factory.makeConnectingOverlayViewModel(cancellation: cancellation)

            if window.isVisible, NSApp.occlusionState.contains(.visible) {
                showLoadingOverlay(with: overlayViewModel!)
            }
        } else {
            switch appStateManager.state {
            case .connected:
                removeConnectingOverlay(animated: true)
            default:
                removeConnectingOverlay()
            }
        }

        if window.styleMask.contains(.fullScreen) {
            expandButton.isHidden = true
        }
    }

    private func removeConnectingOverlay(animated: Bool = false) {
        guard let window = view.window else { return }

        overlayViewModel = nil

        if let overlayWindowController, let overlayWindow = overlayWindowController.window, let viewController = overlayWindowController.contentViewController as? ConnectingViewController {
            connectionOverlay.stopBlurAnimation()
            viewController.stopAnimatingFade()

            if animated {
                if !connectionOverlay.isHidden {
                    connectionOverlay.removeBlur(over: Dimensions.overlayFadeDuration) { [weak self] in
                        guard let self else {
                            return
                        }

                        connectionOverlay.isHidden = true
                    }
                }

                viewController.fade(over: Dimensions.overlayFadeDuration, completion: { [weak self] in
                    window.removeChildWindow(overlayWindow)
                    overlayWindowController.close()
                    self?.overlayWindowController = nil
                })
            } else {
                connectionOverlay.isHidden = true

                window.removeChildWindow(overlayWindow)
                overlayWindowController.close()
                self.overlayWindowController = nil
            }
        }
    }

    private func resizeOverlayWindow() {
        guard let overlayWindowController,
              let window = view.window,
              let contentView = window.contentView else { return }

        let windowRect = window.frame
        let contentRect = contentView.frame

        overlayWindowController.window?.setFrame(CGRect(x: windowRect.origin.x, y: windowRect.origin.y, width: contentRect.width, height: contentRect.height), display: true)
    }

    private func buildViewHierarchy(in rootView: NSView) {
        for item in [allThings, connectionOverlay] {
            item.translatesAutoresizingMaskIntoConstraints = false
            rootView.addSubview(item)
        }

        for item in [sidebarContainerView, mapSectionViewContainer, expandButton] {
            item.translatesAutoresizingMaskIntoConstraints = false
            allThings.addSubview(item)
        }

        for item in [activeControllerViewContainer, tabBarControllerViewContainer, headerControllerViewContainer, announcementsControllerViewContainer] {
            item.translatesAutoresizingMaskIntoConstraints = false
            sidebarContainerView.addSubview(item)
        }

        connectionOverlay.isHidden = true
    }

    private func setupLayoutConstraints(in rootView: NSView) {
        let announcementsPreferredWidth = announcementsControllerViewContainer.widthAnchor.constraint(equalToConstant: Dimensions.announcementsWidth)
        announcementsPreferredWidth.priority = .defaultLow
        let announcementsPreferredHeight = announcementsControllerViewContainer.heightAnchor.constraint(equalToConstant: Dimensions.announcementsHeight)
        announcementsPreferredHeight.priority = .defaultLow

        let headerPreferredHeight = headerControllerViewContainer.heightAnchor.constraint(equalToConstant: Dimensions.headerPreferredHeight)
        headerPreferredHeight.priority = .defaultLow

        expandButtonLeading = mapSectionViewContainer.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor)

        NSLayoutConstraint.activate([
            allThings.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            allThings.topAnchor.constraint(equalTo: rootView.topAnchor),
            allThings.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            allThings.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            connectionOverlay.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            connectionOverlay.topAnchor.constraint(equalTo: rootView.topAnchor),
            connectionOverlay.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            connectionOverlay.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            sidebarContainerView.leadingAnchor.constraint(equalTo: allThings.leadingAnchor),
            sidebarContainerView.topAnchor.constraint(equalTo: allThings.topAnchor),
            sidebarContainerView.bottomAnchor.constraint(equalTo: allThings.bottomAnchor),
            sidebarContainerView.widthAnchor.constraint(equalToConstant: Dimensions.sidebarWidth),

            mapSectionViewContainer.topAnchor.constraint(equalTo: allThings.topAnchor),
            mapSectionViewContainer.trailingAnchor.constraint(equalTo: allThings.trailingAnchor),
            mapSectionViewContainer.bottomAnchor.constraint(equalTo: allThings.bottomAnchor),
            mapSectionViewContainer.leadingAnchor.constraint(equalTo: sidebarContainerView.trailingAnchor),

            expandButton.topAnchor.constraint(equalTo: allThings.topAnchor, constant: Dimensions.expandButtonTopOffset),
            expandButton.widthAnchor.constraint(equalToConstant: Dimensions.expandButtonWidth),
            expandButton.heightAnchor.constraint(equalToConstant: Dimensions.expandButtonHeight),
            expandButtonLeading,

            headerControllerViewContainer.leadingAnchor.constraint(equalTo: sidebarContainerView.leadingAnchor),
            headerControllerViewContainer.topAnchor.constraint(equalTo: sidebarContainerView.topAnchor),
            headerControllerViewContainer.trailingAnchor.constraint(equalTo: sidebarContainerView.trailingAnchor),
            headerPreferredHeight,

            tabBarControllerViewContainer.topAnchor.constraint(equalTo: headerControllerViewContainer.bottomAnchor),
            tabBarControllerViewContainer.leadingAnchor.constraint(equalTo: sidebarContainerView.leadingAnchor),
            tabBarControllerViewContainer.trailingAnchor.constraint(equalTo: sidebarContainerView.trailingAnchor),
            tabBarControllerViewContainer.heightAnchor.constraint(equalToConstant: Dimensions.tabBarHeight),

            activeControllerViewContainer.topAnchor.constraint(equalTo: tabBarControllerViewContainer.bottomAnchor),
            activeControllerViewContainer.leadingAnchor.constraint(equalTo: sidebarContainerView.leadingAnchor),
            activeControllerViewContainer.trailingAnchor.constraint(equalTo: sidebarContainerView.trailingAnchor),
            activeControllerViewContainer.bottomAnchor.constraint(equalTo: sidebarContainerView.bottomAnchor),

            announcementsControllerViewContainer.topAnchor.constraint(equalTo: sidebarContainerView.topAnchor, constant: Dimensions.announcementsTopOffset),
            announcementsControllerViewContainer.trailingAnchor.constraint(equalTo: sidebarContainerView.trailingAnchor, constant: Dimensions.announcementsTrailingOffset),
            announcementsPreferredWidth,
            announcementsPreferredHeight,
            announcementsControllerViewContainer.widthAnchor.constraint(lessThanOrEqualToConstant: Dimensions.announcementsWidth),
            announcementsControllerViewContainer.heightAnchor.constraint(lessThanOrEqualToConstant: Dimensions.announcementsHeight),
        ])
    }

    private func setupMainView() {
        view.wantsLayer = true
    }

    private func setupHeader() {
        headerViewModel = factory.makeHeaderViewModel()
        headerViewController = HeaderViewController(viewModel: headerViewModel!)
        headerViewController.announcementsButtonPressed = { [weak self] in
            self?.announcementsViewModel.open()
        }
        headerControllerViewContainer.pin(viewController: headerViewController)

        expandButton.target = self
        expandButton.action = #selector(expandButtonAction(_:))
        expandButton.expandState = .compact
    }

    private func setupTabBar() {
        tabBarControllerViewContainer.pin(viewController: tabBarViewController)
    }

    private func setupMapSection() {
        mapSectionViewContainer.pin(viewController: mapSectionViewController)
    }

    private func setViewController(forTab tab: SidebarTab) {
        let newViewController: NSViewController = switch tab {
        case .countries:
            countriesSectionViewController
        case .profiles:
            profileSectionViewController
        }
        if let activeController {
            activeControllerViewContainer.willRemoveSubview(activeController.view)
            activeController.view.removeFromSuperview()
            activeController.removeFromParent()
        }
        activeController = newViewController
        activeControllerViewContainer.pin(viewController: activeController)
    }

    @objc
    private func expandButtonAction(_: NSButton) {
        store.send(.expandButtonTapped)
        applySidebarState()

        let mapContainerWidth = store.mapWidth > Dimensions.expandButtonWidth
            ? store.mapWidth
            : Dimensions.defaultMapContainerWidth

        if expandButton.expandState == .compact {
            if var frame = view.window?.frame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Dimensions.animationDuration
                    frame.size.width = Dimensions.sidebarWidth + mapContainerWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                }
            }
        } else {
            if var frame = view.window?.frame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Dimensions.animationDuration
                    frame.size.width = Dimensions.sidebarWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                }
            }
        }
    }

    private func applySidebarState() {
        let selectedTab = store.selectedTab
        if tabBarViewController.activeTab != selectedTab {
            tabBarViewController.activeTab = selectedTab
        }
        setViewController(forTab: selectedTab)
        applyExpandState(store.expandState)
        resizeOverlayWindow()
    }

    private func applyExpandState(_ state: SidebarFeature.State.ExpandState) {
        switch state {
        case .compact:
            expandButton.expandState = .compact
            expandButtonLeading.constant = 0.0
            expandButton.setAccessibilityLabel(Localizable.mapShow)
        case .expanded:
            expandButton.expandState = .expanded
            expandButtonLeading.constant = -Dimensions.expandButtonWidth
            expandButton.setAccessibilityLabel(Localizable.mapHide)
        }
    }

    private func applyLoadingOverlayState() {
        let shouldShowOverlay = store.isLoadingOverlayVisible
        guard renderedLoadingOverlayVisible != shouldShowOverlay else { return }
        renderedLoadingOverlayVisible = shouldShowOverlay

        if shouldShowOverlay {
            fadeOutOverlayTask?.cancel()
            if overlayWindowController == nil {
                loading(show: true)
            }
        } else {
            loading(show: false)
        }
    }
}

extension SidebarViewController {
    private enum Dimensions {
        static let sidebarWidth = UIConstants.Windows.sidebarWidth
        static let expandButtonWidth: CGFloat = 28
        static let expandButtonHeight: CGFloat = 26
        static let expandButtonTopOffset: CGFloat = 20
        static let tabBarHeight: CGFloat = 50
        static let initialViewHeight: CGFloat = 600
        static let defaultMapContainerWidth: CGFloat = 600
        static let announcementsWidth: CGFloat = 300
        static let announcementsHeight: CGFloat = 200
        static let announcementsTopOffset: CGFloat = 45
        static let announcementsTrailingOffset: CGFloat = -20
        static let headerPreferredHeight: CGFloat = 200

        static let animationDuration: CGFloat = 0.4
        static let overlayFadeDuration: CGFloat = 0.5
        static let connectedOverlayDelay: TimeInterval = 3.0
    }
}
