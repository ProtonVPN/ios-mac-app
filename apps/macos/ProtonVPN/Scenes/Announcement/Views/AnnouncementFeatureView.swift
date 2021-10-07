//
//  AnnouncementFeatureView.swift
//  ProtonVPN-mac
//
//  Created by Igor Kulman on 07.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Cocoa
import SDWebImage
import vpncore

final class AnnouncementFeatureView: NSView {
    @IBOutlet private weak var iconImageView: NSImageView!
    @IBOutlet private weak var titleLabel: NSTextField!
    @IBOutlet private var contentView: NSView!

    let model: OfferFeature

    init(model: OfferFeature) {
        self.model = model
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        Bundle.main.loadNibNamed("AnnouncementFeatureView", owner: self, topLevelObjects: nil)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        contentView.pinTo(view: self)

        titleLabel.textColor = .protonWhite()
        titleLabel.stringValue = model.text

        if let url = URL(string: model.iconURL) {
            iconImageView.sd_setImage(with: url, completed: nil)
        }
    }
}
