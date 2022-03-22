//
//  UserAccountUpdateViewController.swift
//  ProtonVPN - Created on 05.04.21.
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

import UIKit
import vpncore

class UserAccountUpdateViewController: UIViewController {

    @IBOutlet private weak var reconnectionView: UIView!
    @IBOutlet private weak var serversView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLbl: UILabel!
    @IBOutlet private weak var descriptionLbl: UILabel!
    
    @IBOutlet private weak var featuresTitleLbl: UILabel!
    
    @IBOutlet private weak var primaryActionBtn: ProtonButton!
    @IBOutlet private weak var secondActionBtn: UIButton!
    
    @IBOutlet private weak var feature1View: UIView!
    @IBOutlet private weak var feature1Lbl: UILabel!
    
    @IBOutlet private weak var feature2View: UIView!
    @IBOutlet private weak var feature2Lbl: UILabel!
    
    @IBOutlet private weak var feature3View: UIView!
    @IBOutlet private weak var feature3Lbl: UILabel!
    
    @IBOutlet private weak var fromServerTitleLbl: UILabel!
    @IBOutlet private weak var fromServerIV: UIImageView!
    @IBOutlet private weak var fromServerLbl: UILabel!
    
    @IBOutlet private weak var toServerTitleLbl: UILabel!
    @IBOutlet private weak var toServerIV: UIImageView!
    @IBOutlet private weak var toServerLbl: UILabel!
    
    private let alert: UserAccountUpdateAlert
    private let planService: PlanService?
    private lazy var serverManager: ServerManager = ServerManagerImplementation.instance(forTier: 2, serverStorage: ServerStorageConcrete())
    
    var dismissCompletion: (() -> Void)?
    
    init(alert: UserAccountUpdateAlert, planService: PlanService?) {
        self.alert = alert
        self.planService = planService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serversView.layer.cornerRadius = 8
        serversView.layer.borderWidth = 1
        serversView.layer.borderColor = UIColor.secondaryBackgroundColor().cgColor
        titleLbl.text = alert.title
        descriptionLbl.text = alert.message
        
        imageView.isHidden = alert.imageName == nil
        if let imageName = alert.imageName { imageView.image = UIImage(named: imageName) }
        
        setupFeatures()
        setupActions()
        setupServers()
    }
    
    // MARK: - Private
    
    private func setupFeatures() {
        feature1View.isHidden = !alert.displayFeatures
        feature2View.isHidden = !alert.displayFeatures
        feature3View.isHidden = !alert.displayFeatures
        featuresTitleLbl.isHidden = !alert.displayFeatures
        guard alert.displayFeatures else { return }
        feature1Lbl.text = LocalizedString.subscriptionUpgradeOption1(serverManager.grouping(for: .standard).count)
        feature2Lbl.text = LocalizedString.subscriptionUpgradeOption2(AccountPlan.plus.devicesCount)
        feature3Lbl.text = LocalizedString.subscriptionUpgradeOption3
    }
    
    private func setupActions() {
        primaryActionBtn.isHidden = true
        secondActionBtn.isHidden = true
        
        if let mainAction = alert.actions.first {
            primaryActionBtn.setTitle(mainAction.title.uppercased(), for: .normal)
            primaryActionBtn.isHidden = false
        }
        
        if let secondAction = alert.actions.last {
            secondActionBtn.setTitle(secondAction.title.uppercased(), for: .normal)
            secondActionBtn.isHidden = false
        }
    }
    
    private func setupServers() {
        reconnectionView.isHidden = true
        
        guard let fromServer = alert.reconnectionInfo?.from,
              let toServer = alert.reconnectionInfo?.to else {
            return
        }
        
        reconnectionView.isHidden = false
        setServerHeader(fromServer, LocalizedString.fromServerTitle, fromServerIV, fromServerLbl, fromServerTitleLbl)
        setServerHeader(toServer, LocalizedString.toServerTitle, toServerIV, toServerLbl, toServerTitleLbl)
    }
    
    private func setServerHeader( _ server: ServerModel, _ headerFormat: (String) -> String, _ flagIV: UIImageView, _ serverName: UILabel, _ serverHeader: UILabel ) {
        let tiers = [LocalizedString.tierFree, LocalizedString.tierBasic, LocalizedString.tierPlus, LocalizedString.tierVisionary]
        serverName.text = server.name
        flagIV.image = UIImage.flag(countryCode: server.countryCode)
        serverHeader.text = headerFormat(tiers[server.tier])
    }
    
    // MARK: - Actions
    
    @IBAction private func didTapPrimaryAction(_ sender: Any) {
        alert.actions.first?.handler?()
        planService?.presentPlanSelection()
        dismissCompletion?()
    }
    
    @IBAction private func didTapSecondAction(_ sender: Any) {
        alert.actions.last?.handler?()
        dismissCompletion?()
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func didTapDismissBtn(_ sender: Any) {
        dismissCompletion?()
        dismiss(animated: true, completion: nil)
    }
}
