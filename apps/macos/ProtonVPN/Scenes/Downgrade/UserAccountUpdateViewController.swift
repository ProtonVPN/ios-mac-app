//
//  UserAccountUpdateViewController.swift
//  ProtonVPN - Created on 06.04.21.
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

import CommonNetworking
import LegacyCommon
import Persistence
import VPNAppCore

import Domain
import Ergonomics
import Strings
import Theme

class UserAccountUpdateViewController: NSViewController {
    @IBOutlet var serversView: NSView!
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var titleLbl: NSTextField!
    @IBOutlet var descriptionLbl: NSTextField!
    @IBOutlet var offsetView: NSView!

    @IBOutlet var featuresTitleLbl: NSTextField!

    @IBOutlet var primaryActionBtn: NSButton!
    @IBOutlet var secondActionBtn: NSButton!

    @IBOutlet var feature1View: NSView!
    @IBOutlet var feature1Lbl: NSTextField!

    @IBOutlet var feature2View: NSView!
    @IBOutlet var feature2Lbl: NSTextField!

    @IBOutlet var feature3View: NSView!
    @IBOutlet var feature3Lbl: NSTextField!

    @IBOutlet var fromServerTitleLbl: NSTextField!
    @IBOutlet var fromServerIV: NSImageView!
    @IBOutlet var fromServerLbl: NSTextField!

    @IBOutlet var fromToArrow: NSImageView!

    @IBOutlet var toServerTitleLbl: NSTextField!
    @IBOutlet var toServerIV: NSImageView!
    @IBOutlet var toServerLbl: NSTextField!

    private let alert: UserAccountUpdateAlert

    var dismissCompletion: (() -> Void)?

    init(alert: UserAccountUpdateAlert) {
        self.alert = alert
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Proton VPN"
        view.wantsLayer = true
        serversView.wantsLayer = true
        DarkAppearance {
            view.layer?.backgroundColor = .cgColor(.background, .weak)
            serversView.layer?.backgroundColor = .cgColor(.background, .weak)
            fromToArrow.image = AppTheme.Icon.arrowRight.colored(.weak)
        }
        serversView.layer?.cornerRadius = 8

        if alert is MaxSessionsAlert {
            imageView.image = Asset.sessionsLimit.image
        } else {
            imageView.isHidden = true
        }

        titleLbl.stringValue = alert.title ?? ""
        descriptionLbl.stringValue = alert.message ?? ""

        setupFeatures()
        setupActions()
        setupServers()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        alert.dismiss?()
    }

    // MARK: - Private

    private func setupFeatures() {
        feature1View.isHidden = !alert.displayFeatures
        feature2View.isHidden = !alert.displayFeatures
        feature3View.isHidden = !alert.displayFeatures
        featuresTitleLbl.isHidden = !alert.displayFeatures
        guard alert.displayFeatures else { return }

        @Dependency(\.serverRepository) var repository
        feature1Lbl.stringValue = Localizable.subscriptionUpgradeOption1(repository.countryCount())
        feature2Lbl.stringValue = Localizable.subscriptionUpgradeOption2(DomainConstants.maxDeviceCount)
        feature3Lbl.stringValue = Localizable.subscriptionUpgradeOption3
    }

    private func setupActions() {
        primaryActionBtn.isHidden = true
        secondActionBtn.isHidden = true

        if let mainAction = alert.actions.first {
            primaryActionBtn.title = mainAction.title.capitalized
            primaryActionBtn.isHidden = false
        }

        if let secondAction = alert.actions.last {
            secondActionBtn.title = secondAction.title.capitalized
            secondActionBtn.isHidden = false
        }
    }

    private func setupServers() {
        offsetView.isHidden = true
        serversView.isHidden = true
        guard let reconnectInfo = alert.reconnectInfo else {
            return
        }

        offsetView.isHidden = false
        serversView.isHidden = false
        setServerHeader(reconnectInfo.fromServer, Localizable.fromServerTitle, fromServerIV, fromServerLbl, fromServerTitleLbl)
        setServerHeader(reconnectInfo.toServer, Localizable.toServerTitle, toServerIV, toServerLbl, toServerTitleLbl)
    }

    private func setServerHeader(
        _ server: ReconnectInfo.Server,
        _ header: String,
        _ flagIV: NSImageView,
        _ serverName: NSTextField,
        _ serverHeader: NSTextField
    ) {
        serverName.stringValue = server.name
        flagIV.image = server.image
        serverHeader.stringValue = header
    }

    // MARK: - Actions

    @IBAction func didTapPrimaryAction(_: Any) {
        alert.actions.first?.handler?()

        Task {
            @Dependency(\.sessionService) var sessionService
            @Dependency(\.linkOpener) var linkOpener

            guard let url = await sessionService.getPlanSession(mode: .upgrade) else { return }
            linkOpener.open(url)
        }

        dismissCompletion?()
        dismiss(nil)
    }

    @IBAction func didTapSecondAction(_: Any) {
        alert.actions.last?.handler?()
        dismissCompletion?()
        dismiss(nil)
    }
}
