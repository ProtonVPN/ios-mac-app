//
//  PlanInfoView.swift
//  ProtonVPN - Created on 2020-03-09.
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

class PlanInfoView: UIView {

    // Views
    @IBOutlet var backgroundView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var stackView: UIStackView!
    
    public var plan: AccountPlan! {
        didSet {
            fillPoints()
            fillViews()
        }
    }
    private var points: [String] = []
    
    override func awakeFromNib() {
        self.translatesAutoresizingMaskIntoConstraints = false
        super.awakeFromNib()
        setupRoundedCorners()
        
        titleLabel.textColor = .protonGreen()
    }
    
    private func setupRoundedCorners() {
        backgroundView.backgroundColor = .protonGrey()
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 10
        
        self.layer.shadowRadius = 4
        self.layer.shadowOpacity = 0.67
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    
    private lazy var serversManager: ServerManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
    
    private func fillPoints() {
        var newPoints = [String]()
        let countriesCount = serversManager.grouping(for: .standard).count
        switch plan {
        case .basic:
            newPoints.append(LocalizedString.countriesCount(countriesCount))
            newPoints.append(LocalizedString.plansConnections(plan.devicesCount))
            newPoints.append(plan.speedDescription)
            
        case .plus:
            newPoints.append(LocalizedString.countriesCount(countriesCount))
            newPoints.append(LocalizedString.plansConnections(plan.devicesCount))
            newPoints.append(plan.speedDescription)
            newPoints.append(LocalizedString.featureBlockedContent)
            newPoints.append(LocalizedString.featureTor)
            newPoints.append(LocalizedString.featureSecureCore)
            newPoints.append(LocalizedString.featureBt)
            newPoints.append(LocalizedString.adblockerNetshieldFeature)

        default:
            break
        }
        
        points = newPoints
    }
    
    private func fillViews() {
        titleLabel.text = plan.displayName
        
        stackView.arrangedSubviews.forEach({view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        })
        
        for point in points {
            let holderView = UIView()
            holderView.translatesAutoresizingMaskIntoConstraints = false
            
            let titleView = UILabel()
            titleView.translatesAutoresizingMaskIntoConstraints = false
            titleView.text = point
            
            let tickView = UIImageView(image: UIImage(named: "checkbox_tick"))
            tickView.translatesAutoresizingMaskIntoConstraints = false
            tickView.tintColor = UIColor.protonGreen()
            
            holderView.add(subView: titleView, withTopMargin: 0, rightMargin: nil, bottomMargin: 0, leftMargin: 0)
            holderView.add(subView: tickView, withTopMargin: nil, rightMargin: 0, bottomMargin: nil, leftMargin: nil)
            tickView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor, constant: 0).isActive = true
            tickView.leftAnchor.constraint(equalTo: titleView.rightAnchor).isActive = true
            
            stackView.addArrangedSubview(holderView)
        }
        
    }
    
}
