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

import Announcement
import Cocoa
import Combine
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Strings
import Theme
import VPNShared

final class SidebarViewController: NSViewController, NSWindowDelegate {
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

    private var connectingViewController: ConnectingViewController?
    private var isAnimatingMapResize = false
    // Retain header view model to set `changeServerStateUpdated` when needed
    private var headerViewModel: HeaderViewModel?

    typealias Factory = AnnouncementsViewModelFactory
        & CoreAlertServiceFactory
        & HeaderViewModelFactory
        & MapSectionViewModelFactory
        & ProfileManagerFactory

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
            navService: navService,
            alertService: factory.makeCoreAlertService(),
            profileManager: factory.makeProfileManager()
        )
        return ProfileSectionViewController(viewModel: viewModel)
    }()

    private lazy var mapHeaderViewModel: MapHeaderViewModel = { [unowned self] in
        return MapHeaderViewModel()
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
        navService: NavigationService,
        factory: Factory
    ) {
        let profileManager = factory.makeProfileManager()
        let store = Store(initialState: .init()) {
            SidebarFeature(
                environment: .init(
                    sidebarWidth: Dimensions.sidebarWidth,
                    expandButtonWidth: Dimensions.expandButtonWidth,
                    defaultMapWidth: Dimensions.defaultMapContainerWidth
                )
            )
        } withDependencies: {
            $0.sidebarProfileNameResolver = SidebarProfileNameResolver(
                profileName: { profileID in
                    profileManager.profile(withId: profileID)?.name
                }
            )
        }

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
            store.send(.windowDidResize(width: window.frame.width, height: window.frame.height))
        }

        applyLoadingOverlayState()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyExpandButtonLayoutDirection()
    }

    override func mouseDown(with _: NSEvent) {
        store.send(.mouseDown)
        view.window?.makeFirstResponder(nil)
    }

    // MARK: - Private

    private func presentConnectingOverlay() {
        guard connectingViewController == nil,
              let connectingOverlayStore = store.scope(state: \.connectingOverlay, action: \.connectingOverlay) else {
            return
        }

        let viewController = ConnectingViewController(store: connectingOverlayStore)
        connectingViewController = viewController

        addChild(viewController)
        let overlayView = viewController.view
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        // Add above connectionOverlay so the blur is between allThings and the overlay UI.
        view.addSubview(overlayView, positioned: .above, relativeTo: connectionOverlay)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        connectionOverlay.isHidden = false
    }

    private func dismissConnectingOverlay() {
        guard let viewController = connectingViewController else { return }
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
        connectingViewController = nil
        connectionOverlay.isHidden = true
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
        applyExpandButtonLayoutDirection()
    }

    private func setupTabBar() {
        tabBarControllerViewContainer.pin(viewController: tabBarViewController)
        tabBarViewController.onTabChanged = { [weak self] tab in
            self?.store.send(.tabChanged(tab))
        }
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
        if activeController === newViewController {
            return
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

        let targetWidth: CGFloat = if store.expandState == .expanded {
            Dimensions.sidebarWidth + mapContainerWidth
        } else {
            Dimensions.sidebarWidth
        }
        animateMapResize(targetWidth: targetWidth)
    }

    private func animateMapResize(targetWidth: CGFloat) {
        guard var frame = view.window?.frame else { return }
        isAnimatingMapResize = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Dimensions.animationDuration
            frame.size.width = targetWidth
            self.view.window?.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            isAnimatingMapResize = false
            applySidebarState()
        }
    }

    private func applyExpandState(_ state: SidebarFeature.State.ExpandState) {
        guard !isAnimatingMapResize else { return }
        expandButton.isHidden = store.isExpandButtonHidden
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

    private func applyExpandButtonLayoutDirection() {
        switch view.userInterfaceLayoutDirection {
        case .leftToRight:
            expandButton.transform = NSAffineTransform()
        case .rightToLeft:
            let transform = NSAffineTransform()
            transform.translateX(by: Dimensions.expandButtonWidth, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            expandButton.transform = transform
        @unknown default:
            expandButton.transform = NSAffineTransform()
        }
        expandButton.needsDisplay = true
    }

    private func applySidebarState() {
        let selectedTab = store.selectedTab
        if tabBarViewController.activeTab != selectedTab {
            tabBarViewController.activeTab = selectedTab
        }
        setViewController(forTab: selectedTab)
        applyExpandState(store.expandState)
    }

    private func applyLoadingOverlayState() {
        if store.shouldPresentLoadingOverlay {
            if connectingViewController == nil {
                presentConnectingOverlay()
            }
        } else if connectingViewController != nil {
            dismissConnectingOverlay()
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
    }
}
