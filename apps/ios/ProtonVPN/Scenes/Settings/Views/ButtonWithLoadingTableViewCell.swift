//
//  Created on 03/02/2022.
//
//  Copyright (c) 2022 Proton AG
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

import UIKit

final class ButtonWithLoadingTableViewCell: UITableViewCell {
    
    @IBOutlet private var button: UIButton!
    @IBOutlet private var loading: UIActivityIndicatorView!
    
    var controller: ButtonWithLoadingIndicatorController? {
        didSet {
            controller?.startLoading = { [weak self] in
                self?.loading.isHidden = false
                self?.loading.startAnimating()
            }
            controller?.stopLoading = { [weak self] in
                self?.loading.isHidden = true
                self?.loading.stopAnimating()
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .secondaryBackgroundColor()
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
    }
    
    func setup(title: String,
               accessibilityIdentifier: String?,
               color: UIColor,
               controller: ButtonWithLoadingIndicatorController) {
        self.button.setTitle(title, for: .normal)
        self.button.setTitleColor(color, for: .normal)
        self.button.accessibilityIdentifier = accessibilityIdentifier
        self.controller = controller
    }
    
    @IBAction private func onPressed(_ sender: Any) {
        assert(controller != nil, "It's requires for the cell to have a controller associated")
        controller?.onPressed()
    }
}
