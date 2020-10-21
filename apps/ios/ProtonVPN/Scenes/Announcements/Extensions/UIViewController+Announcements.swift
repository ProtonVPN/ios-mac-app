//
//  UIViewController+Announcements.swift
//  ProtonVPN - Created on 2020-10-21.
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

extension UIViewController {
    
    @objc func setupAnnouncements() {
        guard let viewModel = AnnouncementButtonViewModel.shared, viewModel.showAnnouncements else {
            navigationItem.leftBarButtonItem = nil
            return
        }
        
        if navigationItem.leftBarButtonItem == nil {
            navigationItem.setLeftBarButton(UIBarButtonItem(image: UIImage(named: "bell"), style: .plain, target: self, action: #selector(announcementsButtonTapped)), animated: false)
        }
        
        renderAnnouncementsButtonBadge()
        // Button may not have been shown yet and thhis case bagde will not be added, so run this a little later
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
            self?.renderAnnouncementsButtonBadge()
        })
    }
    
    func renderAnnouncementsButtonBadge() {
        if AnnouncementButtonViewModel.shared.hasUnreadAnnouncements {
            self.navigationItem.leftBarButtonItem?.addBadge(offset: CGPoint(x: -9, y: 10), color: .protonGreen())
        } else {
            self.navigationItem.leftBarButtonItem?.removeBadge()
        }
    }
    
    @IBAction func announcementsButtonTapped() {
        let viewModel = AnnouncementButtonViewModel.shared
        if let controller = viewModel?.announcementsViewController() {
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    
}
