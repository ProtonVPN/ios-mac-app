//
//  AnnouncementDetailViewController.swift
//  iOS
//
//  Created by Igor Kulman on 05.10.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import UIKit
import vpncore

final class AnnouncementDetailViewController: UIViewController {

    @IBOutlet private weak var closeButton: UIButton!

    var cancelled: (() -> Void)?

    private let data: OfferPanel

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(_ data: OfferPanel) {
        self.data = data
        super.init(nibName: "AnnouncementDetailViewController", bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .protonGrey()
        closeButton.setImage(closeButton.imageView?.image?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.tintColor = .protonWhite()
    }

    @IBAction private func closeButtonTapped(_ sender: Any) {
        cancelled?()
    }
}
