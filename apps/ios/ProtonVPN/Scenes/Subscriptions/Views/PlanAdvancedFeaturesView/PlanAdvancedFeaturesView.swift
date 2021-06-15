//
//  PlanAdvancesFeaturesView.swift
//  ProtonVPN - Created on 03/09/2019.
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

class PlanAdvancedFeaturesView: UIView {

    @IBOutlet var backgroundView: UIView!
    @IBOutlet var popularHolder: UIView!
    @IBOutlet var popularLabel: UILabel!
    @IBOutlet var ticks: [UIImageView]!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var serversLabel: UILabel!
    @IBOutlet var serversValueLabel: UILabel!
    @IBOutlet var speedLabel: UILabel!
    @IBOutlet var speedValueLabel: UILabel!
    @IBOutlet var connectionsLabel: UILabel!
    @IBOutlet var connectionsValueLabel: UILabel!
    @IBOutlet var adblockerNetshieldValueLabel: UILabel!
    @IBOutlet var streamingLabel: UILabel!
    @IBOutlet var torLabel: UILabel!
    @IBOutlet var secureCoreLabel: UILabel!
    @IBOutlet var closeButton: ProtonButton!
    
    private lazy var serversManager: ServerManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
    
    public var plan: AccountPlan! {
        didSet {
            fillViews()
        }
    }
    
    override func awakeFromNib() {
        self.translatesAutoresizingMaskIntoConstraints = false
        super.awakeFromNib()
        setupDesign()
        translate()
    }
    
    private func fillViews() {
        titleLabel.text = plan.displayName
        serversValueLabel.text = LocalizedString.countriesCount(serversManager.grouping(for: .standard).count)
        speedValueLabel.text = plan.speed
        connectionsValueLabel.text = "\(plan.devicesCount)"
    }
 
    private func setupDesign() {
        ticks.forEach { tickImageView in
            tickImageView.tintColor = .protonGreen()
        }
        
        [titleLabel, serversValueLabel, speedValueLabel, connectionsValueLabel].forEach { label in
            label?.textColor = .protonGreen()
        }
        
        popularHolder.backgroundColor = .protonGreen()
        
        backgroundView.backgroundColor = .protonGrey()
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 10
        
        self.layer.shadowRadius = 4
        self.layer.shadowOpacity = 0.67
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        popularHolder.layer.masksToBounds = true
        popularHolder.layer.cornerRadius = 3
    }
    
    private func translate() {
        popularLabel.text = LocalizedString.mostPopular
        
        serversLabel.text = LocalizedString.featureServerCount
        speedLabel.text = LocalizedString.featureSpeed
        connectionsLabel.text = LocalizedString.featureConnections
        streamingLabel.text = LocalizedString.featureSecureStreaming
        torLabel.text = LocalizedString.featureTor
        secureCoreLabel.text = LocalizedString.featureSecureCore
        adblockerNetshieldValueLabel.text = LocalizedString.adblockerNetshieldFeature
        closeButton.setTitle(LocalizedString.close, for: .normal)
    }
    
}
