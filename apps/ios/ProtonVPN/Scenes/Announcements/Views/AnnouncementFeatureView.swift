//
//  AnnouncementFeatureView.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 06.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit
import vpncore
import AlamofireImage

final class AnnouncementFeatureView: UIView {

    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    var model: OfferFeature? {
        didSet {
            titleLabel.text = model?.text

            if let iconUrl = model?.iconURL, let url = URL(string: iconUrl) {
                iconImageView.af.cancelImageRequest()
                iconImageView.af.setImage(withURLRequest: URLRequest(url: url))
            }
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        let nib = UINib(nibName: "AnnouncementFeatureView", bundle: nil)
        nib.instantiate(withOwner: self, options: nil)
        contentView.frame = bounds
        addSubview(contentView)

        contentView.backgroundColor = .protonGrey()
        titleLabel.textColor = .protonWhite()
    }
}
