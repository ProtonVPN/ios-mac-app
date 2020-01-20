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
import vpncore

class SidebarViewController: NSViewController, NSWindowDelegate {
    
    private let sidebarWidth = AppConstants.Windows.sidebarWidth
    private let expandButtonWidth: CGFloat = 28
    
    @IBOutlet weak var allThings: NSView!
    
    @IBOutlet weak var headerControllerViewContainer: NSView!
    @IBOutlet weak var tabBarControllerViewContainer: NSView!
    @IBOutlet weak var activeControllerViewContainer: NSView!
    @IBOutlet weak var connectionOverlay: ConnectionOverlay!
    @IBOutlet weak var sidebarContainerView: NSView!
    @IBOutlet weak var mapContainerView: NSView!
    @IBOutlet weak var expandButton: ExpandMapButton!
    @IBOutlet weak var expandButtonLeading: NSLayoutConstraint!
    
    private var headerViewController: HeaderViewController!
    private var activeController: NSViewController!
    private var viewToggle: NSNotification.Name!
    
    private var overlayWindowController: ConnectingWindowController?
    private var fadeOutOverlayTask: DispatchWorkItem?
    private var loading = false
    private var overlayViewModel: ConnectingOverlayViewModel?
    
    var appStateManager: AppStateManager!
    var vpnGateway: VpnGatewayProtocol!
    var navService: NavigationService!
    
    typealias Factory = CountriesSectionViewModelFactory & MapSectionViewModelFactory
    public var factory: Factory!
    
    private lazy var tabBarViewController: SidebarTabBarViewController = {
        return SidebarTabBarViewController()
    }()
    
    private lazy var countriesSectionViewController: CountriesSectionViewController = { [unowned self] in
        let viewModel = factory.makeCountriesSectionViewModel()
        self.viewToggle = viewModel.contentSwitch
        let countriesViewController = CountriesSectionViewController(viewModel: viewModel)
        countriesViewController.sidebarView = sidebarContainerView
        return countriesViewController
    }()
    
    private lazy var profileSectionViewController: ProfileSectionViewController = { [unowned self] in
        let viewModel = ProfilesSectionViewModel(vpnGateway: self.vpnGateway, navService: navService)
        return ProfileSectionViewController(viewModel: viewModel)
    }()
    
    private lazy var mapHeaderViewModel: MapHeaderViewModel = { [unowned self] in
        return MapHeaderViewModel(vpnGateway: self.vpnGateway)
    }()
    
    private lazy var mapSectionViewModel: MapSectionViewModel = {
        return factory.makeMapSectionViewModel(viewToggle: self.viewToggle)
    }()
    
    // MARK: Functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMainView()
        setupHeader()
        setupTabBar()
        tabBarViewController.activeTab = .countries
        
        self.loading(show: false)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appStateChanged),
                                               name: appStateManager.stateChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidResize(_:)),
                                               name: NSWindow.didResizeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidEndLiveResize(_:)),
                                               name: NSWindow.didEndLiveResizeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillEnterFullScreen(_:)),
                                               name: NSWindow.willEnterFullScreenNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowWillExitFullScreen(_:)),
                                               name: NSWindow.willExitFullScreenNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(occlusionStateChanged(_:)),
                                               name: NSApplication.didChangeOcclusionStateNotification,
                                               object: nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.applySidebarAppearance()
        configureExpandButton()
        
        if let overlayViewModel = overlayViewModel, !appStateManager.state.isConnected {
            showLoadingOverlay(with: overlayViewModel)
        } else {
            overlayViewModel = nil
        }
    }
    
    func windowDidResize(_ notification: Notification) {
        configureExpandButton()
        resizeOverlayWindow()
    }
    
    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = view.window else { return }
        let width = window.frame.width
        
        if !window.styleMask.contains(.fullScreen) && self.expandButton.expandState == .expanded && width > sidebarWidth + expandButtonWidth {
            Storage.userDefaults().set(Int(width - sidebarWidth), forKey: AppConstants.UserDefaults.mapWidth)
        }
        
        if width > sidebarWidth + expandButtonWidth && self.expandButton.expandState == .compact {
            self.expandButton.expandState = .expanded
            self.expandButtonLeading.constant = -expandButtonWidth
        }
    }
    
    func windowWillEnterFullScreen(_ notification: Notification) {
        //hide expend button
        self.expandButton.isHidden = true
    }
    
    func windowWillExitFullScreen(_ notification: Notification) {
        //show expend button
        self.expandButton.isHidden = false
    }
    
    func setTab(tab: SidebarTab) {
        tabBarViewController.activeTab = tab
    }
    
    // MARK: - Private
    private func configureExpandButton() {
        guard let window = view.window else { return }
        
        if window.frame.width <= sidebarWidth + expandButtonWidth {
            self.expandButton.expandState = .compact
            self.expandButtonLeading.constant = 0.0
            self.expandButton.setAccessibilityLabel(LocalizedString.mapShow)
        } else {
            self.expandButton.expandState = .expanded
            self.expandButtonLeading.constant = -expandButtonWidth
            self.expandButton.setAccessibilityLabel(LocalizedString.mapHide)
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
    }
    
    private func loading(show: Bool, animateClose: Bool = false) {
        guard let window = view.window else { return }
        
        loading = show
        
        if show {
            removeConnectingOverlay()
            
            overlayViewModel = ConnectingOverlayViewModel(appStateManager: appStateManager, navService: navService, cancellation: { [weak self] in
                guard let `self` = self else { return }
                self.removeConnectingOverlay()
            }, retry: { [weak self] in
                guard let `self` = self else { return }
                self.vpnGateway.retryConnection()
            })
            
            if window.isVisible && NSApp.occlusionState.contains(.visible) {
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
        
        if let overlayWindowController = overlayWindowController, let overlayWindow = overlayWindowController.window, let viewController = overlayWindowController.contentViewController as? ConnectingViewController {
            connectionOverlay.stopBlurAnimation()
            viewController.stopAnimatingFade()
            
            if animated {
                if !connectionOverlay.isHidden {
                    connectionOverlay.removeBlur(over: 0.5) { [weak self] in
                        guard let `self` = self else { return }
                        self.connectionOverlay.isHidden = true
                    }
                }
                
                viewController.fade(over: 0.5, completion: { [unowned self] in
                    window.removeChildWindow(overlayWindow)
                    overlayWindowController.close()
                    self.overlayWindowController = nil
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
            if case AppState.connecting(_) = appStateManager.state, let overlayViewModel = overlayViewModel {
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
        guard let overlayWindowController = overlayWindowController,
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
        let viewModel = HeaderViewModel(vpnGateway: vpnGateway, navService: navService)
        headerViewController = HeaderViewController(viewModel: viewModel)
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
        let newViewController: NSViewController
        switch tab {
        case .countries:
            newViewController = countriesSectionViewController
        case .profiles:
            newViewController = profileSectionViewController
        }
        if let activeController = activeController {
            activeControllerViewContainer.willRemoveSubview(activeController.view)
            activeController.view.removeFromSuperview()
            activeController.removeFromParent()
        }
        activeController = newViewController
        activeControllerViewContainer.pin(viewController: activeController)
    }
    
    @objc private func expandButtonAction(_ sender: NSButton) {
        let savedMapWidth = CGFloat(Storage.userDefaults().integer(forKey: AppConstants.UserDefaults.mapWidth))
        let mapContainerWidth: CGFloat = savedMapWidth > expandButtonWidth ? savedMapWidth : 600
        if expandButton.expandState == .compact {
            if var frame = self.view.window?.frame {
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = 0.4
                    frame.size.width = sidebarWidth + mapContainerWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                })
            }
        } else {
            if var frame = self.view.window?.frame {
                NSAnimationContext.runAnimationGroup({ (context) in
                    context.duration = 0.4
                    frame.size.width = sidebarWidth
                    self.view.window?.animator().setFrame(frame, display: true)
                })
            }
        }
    }
    
    @objc private func appStateChanged() {
        switch appStateManager.state {
        case .preparingConnection, .connecting:
            fadeOutOverlayTask?.cancel()
            if overlayWindowController == nil {
                self.loading(show: true)
            }
        case .connected:
            let delta = 3.0 as TimeInterval
            fadeOutOverlayTask = DispatchWorkItem { [weak self] in
                guard let `self` = self else { return }
                if !self.connectionOverlay.isHidden {
                    self.loading(show: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delta, execute: fadeOutOverlayTask!)
        case .aborted(let userInitiated):
            if userInitiated {
                DispatchQueue.main.async {
                    self.loading(show: false)
                }
            }
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
