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
import Alamofire
import AlamofireImage
import vpncore

extension UIViewController {
    
    @objc func setupAnnouncements() {
        guard let viewModel = AnnouncementButtonViewModel.shared, viewModel.showAnnouncements else {
            navigationItem.leftBarButtonItem = nil
            return
        }

        let setup = { [weak self] in
            self?.renderAnnouncementsButtonBadge()
            // Button may not have been shown yet and this case bagde will not be added, so run this a little later
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: { [weak self] in
                self?.renderAnnouncementsButtonBadge()
            })
        }

        let assign = { [weak self] (button: BadgedBarButtonItem) in
            button.onTouchUpInside = { [weak self] in
                self?.announcementsButtonTapped()
            }
            self?.navigationItem.setLeftBarButton(button, animated: false)
        }
        
        if navigationItem.leftBarButtonItem == nil {
            if let iconUrl = viewModel.iconUrl {
                let downloader = ImageDownloader()
                let urlRequest = URLRequest(url: iconUrl)

                downloader.download(urlRequest, filter: AspectScaledToFillSizeFilter(size: CGSize(width: 24, height: 24)), completion: { (response: AFIDataResponse<Image>) in
                    switch response.result {
                    case let .success(image):
                        assign(BadgedBarButtonItem(withImage: image))
                        setup()
                    case .failure:
                        assign(BadgedBarButtonItem(withImage: UIImage(named: "bell")?.withRenderingMode(.alwaysTemplate)))
                        setup()
                    }
                })
            } else {
                assign(BadgedBarButtonItem(withImage: UIImage(named: "bell")?.withRenderingMode(.alwaysTemplate)))
                setup()
            }
        }

        setup()
    }
    
    func renderAnnouncementsButtonBadge() {
        let button = self.navigationItem.leftBarButtonItem as? BadgedBarButtonItem
        button?.showBadge = AnnouncementButtonViewModel.shared.hasUnreadAnnouncements
    }
    
    @IBAction func announcementsButtonTapped() {
        let viewModel = AnnouncementButtonViewModel.shared
        viewModel?.showAnnouncement()
    }
    
}
