//
//  StreamingServiceCell.swift
//  ProtonVPN - Created on 20.04.21.
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

import Alamofire
import AlamofireImage
import CommonNetworking
import Dependencies
import LegacyCommon
import UIKit

class StreamingServiceCell: UICollectionViewCell {
    private let serviceIV: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let serviceLbl: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    @Dependency(\.propertiesManager) private var propertiesManager

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(serviceLbl)
        contentView.addSubview(serviceIV)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            serviceLbl.topAnchor.constraint(equalTo: contentView.topAnchor),
            serviceLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            serviceLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            serviceLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            serviceIV.topAnchor.constraint(equalTo: contentView.topAnchor),
            serviceIV.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            serviceIV.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            serviceIV.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    public var service: VpnStreamingOption? {
        didSet {
            serviceLbl.text = service?.name
            serviceIV.isHidden = true
            serviceLbl.isHidden = false

            guard propertiesManager.featureFlags.streamingServicesLogos,
                  let icon = service?.icon,
                  let baseUrl = propertiesManager.streamingResourcesUrl,
                  let url = URL(string: baseUrl + icon) else {
                return
            }

            serviceIV.isHidden = false
            serviceLbl.isHidden = true
            serviceIV.af.cancelImageRequest()
            serviceIV.af.setImage(withURLRequest: URLRequest(url: url))
        }
    }
}
