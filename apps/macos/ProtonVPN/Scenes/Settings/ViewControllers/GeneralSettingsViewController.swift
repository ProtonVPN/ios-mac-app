//
//  GeneralViewController.swift
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
import LegacyCommon
import AppKit
import Ergonomics
import Strings

protocol ReloadableViewController: AnyObject {
    func reloadView()
}

final class GeneralSettingsViewController: NSViewController, ReloadableViewController {

    @IBOutlet weak var startOnBootView: SettingsTickboxView!
    @IBOutlet weak var startMinimizedView: SettingsTickboxView!
    @IBOutlet weak var systemNotificationsView: SettingsTickboxView!
    @IBOutlet weak var earlyAccessView: SettingsTickboxView!
    @IBOutlet weak var unprotectedNetworkView: SettingsTickboxView!

    private var viewModel: GeneralSettingsViewModel
    
    required init?(coder: NSCoder) {
        fatalError("Unsupported initializer")
    }
    
    required init(viewModel: GeneralSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: NSNib.Name("GeneralSettings"), bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadView()
    }
    
    private func setupView() {
        view.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
        }
    }
    
    private func setupStartOnBootItem() {
        let viewModel = SettingsTickboxView.ViewModel(labelText: Localizable.startOnBoot, buttonState: viewModel.startOnBoot)
        startOnBootView.setupItem(model: viewModel, delegate: self)
    }
    
    private func setupStartMinimizedItem() {
        let viewModel = SettingsTickboxView.ViewModel(labelText: Localizable.startMinimized, buttonState: viewModel.startMinimized)
        startMinimizedView.setupItem(model: viewModel, delegate: self)
    }
    
    private func setupSystemNotificationsItem() {
        let viewModel = SettingsTickboxView.ViewModel(labelText: Localizable.systemNotifications, buttonState: viewModel.systemNotifications)
        systemNotificationsView.setupItem(model: viewModel, delegate: self)
    }
    
    private func setupEarlyAccessItem() {
        let viewModel = SettingsTickboxView.ViewModel(labelText: Localizable.earlyAccess, buttonState: viewModel.earlyAccess, toolTip: Localizable.earlyAccessTooltip)
        earlyAccessView.setupItem(model: viewModel, delegate: self)
    }

    private func setupUnprotectedNetworkItem() {
        let viewModel = SettingsTickboxView.ViewModel(labelText: Localizable.unprotectedNetwork, buttonState: viewModel.unprotectedNetworkNotifications, toolTip: Localizable.unprotectedNetworkTooltip)
        unprotectedNetworkView.setupItem(model: viewModel, delegate: self)
    }
    
    // MARK: - ReloadableView
    
    func reloadView() {
        setupView()
        setupStartOnBootItem()
        setupStartMinimizedItem()
        setupSystemNotificationsItem()
        setupEarlyAccessItem()
        setupUnprotectedNetworkItem()
    }
}

extension GeneralSettingsViewController: TickboxViewDelegate {

    func upsellTapped(_ tickboxView: SettingsTickboxView) {
        // No upsellable features need to be handled in general settings
    }

    func toggleTickbox(_ tickboxView: SettingsTickboxView, to value: ButtonState) {
        switch tickboxView {
        case startOnBootView:
            viewModel.setStartOnBoot(value == .on)
            setupStartOnBootItem()
        case startMinimizedView:
            viewModel.setStartMinimized(value == .on)
            setupStartMinimizedItem()
        case systemNotificationsView:
            viewModel.setSystemNotifications(value == .on)
            setupSystemNotificationsItem()
        case earlyAccessView:
            viewModel.setEarlyAccess(value == .on)
            setupEarlyAccessItem()
        case unprotectedNetworkView:
            viewModel.setUnprotectedNetworkNotifications(value == .on)
            setupUnprotectedNetworkItem()
        default:
            break
        }
    }
}
