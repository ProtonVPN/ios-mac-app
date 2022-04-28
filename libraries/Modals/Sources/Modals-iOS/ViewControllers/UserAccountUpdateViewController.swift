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
import Modals

class UserAccountUpdateViewController: UIViewController {

    @IBOutlet private weak var reconnectionView: UIView!
    @IBOutlet private weak var serversView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLbl: UILabel!
    @IBOutlet private weak var descriptionLbl: UILabel!
    
    @IBOutlet private weak var featuresTitleLbl: UILabel!
    
    @IBOutlet private weak var primaryActionBtn: UIButton!
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
    
//    var alert: UserAccountUpdateAlert?
    var planService: PlanService?
    var feature: UserAccountUpdateFeature!
    
    var dismissCompletion: (() -> Void)?
    var onPrimaryButtonTap: (() -> Void)?
    
//    init(alert: UserAccountUpdateAlert, planService: PlanService?) {
//        self.alert = alert
//        self.planService = planService
//        super.init(nibName: nil, bundle: nil)
//    }

    // MARK: - View Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        serversView.layer.cornerRadius = 12
        serversView.layer.borderWidth = 1
        serversView.layer.borderColor = colors.secondaryBackground.cgColor
        titleLbl.text = feature.title
        descriptionLbl.text = feature.subtitle

        actionButtonStyle(primaryActionBtn)
        actionTextButtonStyle(secondActionBtn)

         if let image = feature.image {
             imageView.image = image
         } else {
             imageView.isHidden = true
         }
        
        setupFeatures()
        setupActions()
        setupServers()
    }
    
    // MARK: - Private
    
    private func setupFeatures() {
        guard let options = feature.options, !options.isEmpty else {
            [feature1View, feature2View, feature3View, featuresTitleLbl].forEach {
                $0?.isHidden = true
            }
            return
        }
        feature1Lbl.text = options[0]
        feature2Lbl.text = options[1]
        feature3Lbl.text = options[2]
    }
    
    private func setupActions() {
        primaryActionBtn.setTitle(feature.primaryButtonTitle, for: .normal)
        
        if let title = feature.secondaryButtonTitle {
            secondActionBtn.setTitle(title, for: .normal)
            secondActionBtn.isHidden = false
        } else {
            secondActionBtn.isHidden = true
        }
    }
    
    private func setupServers() {
        guard let fromServer = feature.fromServer,
              let toServer = feature.toServer else {
            reconnectionView.isHidden = true
            return
        }

        setServerHeader(fromServer, fromServerIV, fromServerLbl)
        setServerHeader(toServer, toServerIV, toServerLbl)

        fromServerTitleLbl.text = feature.fromServerTitle
        toServerTitleLbl.text = feature.toServerTitle
    }
    
    private func setServerHeader( _ server: UserAccountUpdateFeature.Server, _ flag: UIImageView, _ serverName: UILabel) {
        serverName.text = server.name
        flag.image = server.flag
    }
    
    // MARK: - Actions
    
    @IBAction private func didTapPrimaryAction(_ sender: Any) {
//        planService?.presentPlanSelection()
        onPrimaryButtonTap?()
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func didTapSecondAction(_ sender: Any) {
        dismissCompletion?()
        dismiss(animated: true, completion: nil)
    }
}
