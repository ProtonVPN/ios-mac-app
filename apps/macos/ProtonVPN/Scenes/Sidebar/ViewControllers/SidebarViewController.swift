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
import Dependencies

import Announcement
import LegacyCommon
import VPNShared

import Domain
import Strings

final class SidebarViewController: NSViewController, NSWindowDelegate {
    static let reconnectionNotificationName = Notification.Name("SidebarViewControllerReconnect")

    private let sidebarWidth = AppConstants.Windows.sidebarWidth
    private let expandButtonWidth: CGFloat = 28
    
    @IBOutlet private var allThings: NSView!
    
    @IBOutlet private var headerControllerViewContainer: NSView!
    @IBOutlet private var tabBarControllerViewContainer: NSView!
    @IBOutlet private var activeControllerViewContainer: NSView!
    @IBOutlet private var announcementsControllerViewContainer: NSView!
    @IBOutlet private var connectionOverlay: ConnectionOverlay!
    @IBOutlet private var sidebarContainerView: NSView!
    @IBOutlet private var expandButton: ExpandMapButton!
    @IBOutlet private var expandButtonLeading: NSLayoutConstraint!
    
    private var headerViewController: HeaderViewController!
    private var activeController: NSViewController!
    private var viewToggle: NSNotification.Name!
    
    private var overlayWindowController: ConnectingWindowController?
    private var fadeOutOverlayTask: DispatchWorkItem?
    private var loading = false
    private var overlayViewModel: ConnectingOverlayViewModel?
    // Retain header view model to set `changeServerStateUpdated` when needed
    private var headerViewModel: HeaderViewModel?
    
    var appStateManager: AppStateManager!
    var vpnGateway: VpnGatewayProtocol!
    var navService: NavigationService!
    
    typealias Factory = AnnouncementsViewModelFactory
        & ConnectingOverlayViewModelFactory
        & CoreAlertServiceFactory
        & CountriesSectionViewModelFactory
        & HeaderViewModelFactory
        & MapSectionViewModelFactory
        & ProfileManagerFactory
        & PropertiesManagerFactory
        & SystemExtensionManagerFactory
    public var factory: Factory!
    
    private lazy var tabBarViewController: SidebarTabBarViewController = .init()
    
    private lazy var countriesSectionViewController: CountriesSectionViewController = { [unowned self] in
        let viewModel = factory.makeCountriesSectionViewModel()
        viewToggle = viewModel.contentSwitch
        let countriesViewController = CountriesSectionViewController(viewModel: viewModel)
        countriesViewController.sidebarView = sidebarContainerView
        // Header view model decides when to show a timer for the next free user reconnection. Not to
        // repeat the same logic we have to pass the change to the country list, where we have a banner
        // that changes if server change is not allowed atm.
        headerViewModel?.changeServerStateUpdated = { [weak viewModel] viewState in
            viewModel?.changeServerStateUpdated(to: viewState)
        }
        return countriesViewController
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
    
    private lazy var mapSectionViewModel: MapSectionViewModel = factory.makeMapSectionViewModel(viewToggle: self.viewToggle)

    private lazy var announcementsViewModel: AnnouncementsViewModel = factory.makeAnnouncementsViewModel()
    
    // MARK: Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMainView()
        setupHeader()
        setupTabBar()
        tabBarViewController.activeTab = .countries
        
        loading(show: false)

        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(appStateChanged))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize(_:)),
            name: NSWindow.didEndLiveResizeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillEnterFullScreen(_:)),
            name: NSWindow.willEnterFullScreenNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillExitFullScreen(_:)),
            name: NSWindow.willExitFullScreenNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(occlusionStateChanged(_:)),
            name: NSApplication.didChangeOcclusionStateNotification,
            object: nil
        )
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.applySidebarAppearance()
        configureExpandButton()
        
        if let overlayViewModel, !appStateManager.state.isConnected {
            showLoadingOverlay(with: overlayViewModel)
        } else {
            overlayViewModel = nil
        }
        vpnGateway.postConnectionInformation()
    }

    override func mouseDown(with event: NSEvent) {
        view.window?.makeFirstResponder(nil)
    }
    
    func windowDidResize(_ notification: Notification) {
        configureExpandButton()
        resizeOverlayWindow()
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = view.window else { return }
        let width = window.frame.width
        
        if !window.styleMask.contains(.fullScreen), expandButton.expandState == .expanded, width > sidebarWidth + expandButtonWidth {
            @Dependency(\.defaultsProvider) var provider
            provider.getDefaults().set(Int(width - sidebarWidth), forKey: AppConstants.UserDefaults.mapWidth)
        }
        
        if width > sidebarWidth + expandButtonWidth, expandButton.expandState == .compact {
            expandButton.expandState = .expanded
            expandButtonLeading.constant = -expandButtonWidth
        }
    }
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        // Hide expand button
        expandButton.isHidden = true
    }
    
    func windowWillExitFullScreen(_ notification: Notification) {
        // Show expand button
        expandButton.isHidden = false
    }
    
    func setTab(tab: SidebarTab) {
        tabBarViewController.activeTab = tab
    }
    
    // MARK: - Private

    private func configureExpandButton() {
        guard let window = view.window else { return }
        
        if window.frame.width <= sidebarWidth + expandButtonWidth {
            expandButton.expandState = .compact
            expandButtonLeading.constant = 0.0
            expandButton.setAccessibilityLabel(Localizable.mapShow)
        } else {
            expandButton.expandState = .expanded
            expandButtonLeading.constant = -expandButtonWidth
            expandButton.setAccessibilityLabel(Localizable.mapHide)
        }
        
        switch view.userInterfaceLayoutDirection {
        case .leftToRight:
            expandButton.transform = NSAffineTransform()
        case .rightToLeft:
            expandButton.transform = NSAffineTransform()
            expandButton.transform.translateX(by: expandButton.bounds.size.width, yBy: 0)
            expandButton.transform.scaleX(by: -1, yBy: 1)
        @unknown default:
            expandButton.transform = NSAffineTransform()
        }
    }
    
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
    
    private func loading(show: Bool, animateClose: Bool = false) {
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
                    connectionOverlay.removeBlur(over: 0.5) { [weak self] in
                        guard let self else {
                            return
                        }

                        connectionOverlay.isHidden = true
                    }
                }
                
                viewController.fade(over: 0.5, completion: { [weak self] in
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
    
    @objc private func occlusionStateChanged(_ notification: Notification) {
        if NSApp.occlusionState.contains(.visible) {
            if case AppState.connecting = appStateManager.state, let overlayViewModel {
                showLoadingOverlay(with: overlayViewModel)
            }
        } else if !connectionOverlay.isHidden {
            // There's a bug caused by ConnectingOverlay's use of layerUsesCoreImageFilters when sleeping and then switching users
            // (main thread is blocked due to a graphics-related resource lock).
            // To deal with this, need to make sure all uses of layerUsesCoreImageFilters are set to false when app isn't visible.
            removeConnectingOverlay()
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
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTabChanged(_:)),
                                               name: tabBarViewController.tabChanged,
                                               object: nil)
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
    
    @objc private func expandButtonAction(_ sender: NSButton) {
        @Dependency(\.defaultsProvider) var provider
        let savedMapWidth = CGFloat(provider.getDefaults().integer(forKey: AppConstants.UserDefaults.mapWidth))
        let mapContainerWidth: CGFloat = savedMapWidth > expandButtonWidth ? savedMapWidth : 600
        if expandButton.expandState == .compact {
            if var frame = view.window?.frame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    frame.size.width = sidebarWidth + mapContainerWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                }
            }
        } else {
            if var frame = view.window?.frame {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.4
                    frame.size.width = sidebarWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                }
            }
        }
    }
    
    @objc private func appStateChanged() {
        switch appStateManager.state {
        case .preparingConnection, .connecting:
            fadeOutOverlayTask?.cancel()
            if overlayWindowController == nil {
                loading(show: true)
            }
        case .connected:
            let delta = 3.0 as TimeInterval
            fadeOutOverlayTask = DispatchWorkItem { [weak self] in
                guard let self else {
                    return
                }

                if !connectionOverlay.isHidden {
                    loading(show: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delta, execute: fadeOutOverlayTask!)
        case let .aborted(userInitiated):
            if userInitiated {
                DispatchQueue.main.async {
                    self.loading(show: false)
                }
            }
        case .disconnected:
            loading(show: false)
        default:
            break
        }
    }
    
    @objc private func handleTabChanged(_ notification: Notification) {
        if let tab = notification.object as? SidebarTab {
            setViewController(forTab: tab)
        }
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let viewController = segue.destinationController as? MapSectionViewController {
            viewController.mapHeaderViewModel = mapHeaderViewModel
            viewController.mapSectionViewModel = mapSectionViewModel            
        }
    }
}
