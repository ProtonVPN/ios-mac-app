//
//  OnboardingContentViewController.swift
//  ProtonVPN - Created on 01.07.19.
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

class OnboardingContentViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    let viewModel: OnboardingContentViewModel
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(viewModel: OnboardingContentViewModel) {
        self.viewModel = viewModel
        
        super.init(nibName: "OnboardingContent", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = viewModel.image
        titleLabel.attributedText = viewModel.title.attributed(withColor: .protonConnectGreen(), fontSize: 20, alignment: .center)
        descriptionLabel.attributedText = viewModel.description.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .center)
    }
}
