//
//  SidebarTabBarViewController.swift
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
import Strings

enum SidebarTab: Equatable {
    case countries
    case profiles
}

class SidebarTabBarViewController: NSViewController {
    var onTabChanged: ((SidebarTab) -> Void)?

    private var tabBarView: SidebarTabBarView = .init(frame: .zero)
    private var countriesButton: TabBarButton = .init(frame: .zero)
    private var profilesButton: TabBarButton = .init(frame: .zero)

    var activeTab: SidebarTab? {
        didSet {
            new(tab: activeTab!)
        }
    }

    required init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("Unsupported initializer")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Dimensions.width, height: Dimensions.height))
        view.translatesAutoresizingMaskIntoConstraints = false

        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        countriesButton.translatesAutoresizingMaskIntoConstraints = false
        profilesButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonsContainer = NSView(frame: .zero)
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tabBarView)
        tabBarView.addSubview(buttonsContainer)
        buttonsContainer.addSubview(countriesButton)
        buttonsContainer.addSubview(profilesButton)

        NSLayoutConstraint.activate([
            tabBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarView.topAnchor.constraint(equalTo: view.topAnchor),
            tabBarView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonsContainer.leadingAnchor.constraint(equalTo: tabBarView.leadingAnchor),
            buttonsContainer.trailingAnchor.constraint(equalTo: tabBarView.trailingAnchor),
            buttonsContainer.topAnchor.constraint(equalTo: tabBarView.topAnchor),
            buttonsContainer.bottomAnchor.constraint(equalTo: tabBarView.bottomAnchor),

            countriesButton.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor),
            countriesButton.centerYAnchor.constraint(equalTo: buttonsContainer.centerYAnchor),
            countriesButton.widthAnchor.constraint(equalTo: buttonsContainer.widthAnchor, multiplier: 0.5),
            countriesButton.heightAnchor.constraint(equalTo: buttonsContainer.heightAnchor),

            profilesButton.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor),
            profilesButton.centerYAnchor.constraint(equalTo: buttonsContainer.centerYAnchor),
            profilesButton.widthAnchor.constraint(equalTo: buttonsContainer.widthAnchor, multiplier: 0.5),
            profilesButton.heightAnchor.constraint(equalTo: buttonsContainer.heightAnchor),

            tabBarView.heightAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.height),
            tabBarView.widthAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.width),
        ])

        setupButtons()
    }

    private func setupButtons() {
        countriesButton.title = Localizable.countries
        countriesButton.target = self
        countriesButton.action = #selector(countriesTabAction(_:))

        profilesButton.title = Localizable.profiles
        profilesButton.target = self
        profilesButton.action = #selector(profilesTabAction(_:))

        countriesButton.setAccessibilityIdentifier("CountriesButton")
        profilesButton.setAccessibilityIdentifier("ProfilesButton")
    }

    private func new(tab: SidebarTab) {
        tabBarView.activeTab = tab
        countriesButton.isFocused = tab == .countries
        profilesButton.isFocused = tab == .profiles
        onTabChanged?(tab)
    }

    @objc
    private func countriesTabAction(_: NSButton) {
        if activeTab != .countries {
            activeTab = .countries
        }
    }

    @objc
    private func profilesTabAction(_: NSButton) {
        if activeTab != .profiles {
            activeTab = .profiles
        }
    }

    private enum Dimensions {
        static let width: CGFloat = 340
        static let height: CGFloat = 50
    }
}
