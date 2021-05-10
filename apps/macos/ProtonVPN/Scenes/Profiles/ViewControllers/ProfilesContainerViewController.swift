//
//  ProfilesContainerViewController.swift
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

class ProfilesContainerViewController: NSViewController {
    
    typealias Factory = CreateNewProfileViewModelFactory
    private let factory: Factory
    
    @IBOutlet weak var profilesTabBarControllerViewContainer: NSView!
    @IBOutlet weak var activeControllerViewContainer: NSView!
    
    private let tabChanged = Notification.Name("ProfilesSectionViewControllerTabChanged")
    private let editProfile = Notification.Name("ProfilesSectionViewControllerEditProfile")
    private let viewModel: ProfilesContainerViewModel
    
    private var tabBarViewController: ProfilesTabBarViewController!
    private var activeController: NSViewController?
    
    private lazy var overviewVC: OverviewViewController = { [unowned self] in
        let viewModel = OverviewViewModel(vpnGateway: self.viewModel.vpnGateway)
        self.setUpCallbacks(overview: viewModel)
        let viewController = OverviewViewController(viewModel: viewModel)
        return viewController
    }()
    
    private lazy var createNewProfileVC: CreateNewProfileViewController = { [unowned self] in
        let viewModel = self.factory.makeCreateNewProfileViewModel(editProfile: self.editProfile)
        self.startObserving(createNewProfile: viewModel)
        let viewController = CreateNewProfileViewController(viewModel: viewModel)
        return viewController
    }()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    init(factory: Factory, viewModel: ProfilesContainerViewModel) {
        self.factory = factory
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("ProfilesContainer"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTabBarView()
        setupInitialView()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        view.window?.applyModalAppearance(withTitle: LocalizedString.profilesOverview)
    }
    
    private func setupTabBarView() {
        tabBarViewController = ProfilesTabBarViewController(tabChangedExternally: tabChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(focusTab(_:)),
                                               name: tabBarViewController.tabChanged, object: nil)
        profilesTabBarControllerViewContainer.pin(viewController: tabBarViewController)
    }
    
    private func setupInitialView() {
        switch viewModel.initialTab {
        case .overview:
            set(viewController: overviewVC)
        case .createNewProfile:
            set(viewController: createNewProfileVC)
        }
        NotificationCenter.default.post(name: tabChanged, object: viewModel.initialTab)
    }
    
    private func set(viewController: NSViewController) {
        if let activeController = activeController {
            activeControllerViewContainer.willRemoveSubview(activeController.view)
            activeController.view.removeFromSuperview()
            activeController.removeFromParent()
        }
        activeController = viewController
        activeControllerViewContainer.pin(viewController: activeController!)
    }
    
    private func setUpCallbacks(overview viewModel: OverviewViewModel) {
        viewModel.createNewProfile = { [unowned self] in self.createNewProfile() }
        viewModel.editProfile = { [unowned self] profile in self.editProfile(profile) }
    }
    
    private func startObserving(createNewProfile viewModel: CreateNewProfileViewModel) {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionFinished),
                                               name: viewModel.sessionFinished, object: nil)
    }
    
    private func createNewProfile() {
        set(viewController: createNewProfileVC)
        NotificationCenter.default.post(name: tabChanged, object: ProfilesTab.createNewProfile)
    }
    
    private func editProfile(_ profile: Profile) {
        set(viewController: createNewProfileVC)
        NotificationCenter.default.post(name: tabChanged, object: ProfilesTab.createNewProfile)
        NotificationCenter.default.post(name: editProfile, object: profile)
    }
    
    @objc private func sessionFinished() {
        set(viewController: overviewVC)
        NotificationCenter.default.post(name: tabChanged, object: ProfilesTab.overview)
    }
    
    @objc private func focusTab(_ notification: Notification) {
        if let tab = notification.object as? ProfilesTab {
            switch tab {
            case .overview:
                set(viewController: overviewVC)
            case .createNewProfile:
                set(viewController: createNewProfileVC)
            }
        }
    }
}
