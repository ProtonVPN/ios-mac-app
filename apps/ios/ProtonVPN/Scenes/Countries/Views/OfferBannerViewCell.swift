//
//  OneLineTableViewCell.swift
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
import Theme

class OfferBannerViewCell: UITableViewCell {

    @IBOutlet weak var roundedBackgroundView: UIView!
    @IBOutlet weak var offerImageView: UIImageView!
    @IBOutlet weak var timeRemainingLabel: UILabel!
    @IBOutlet weak var dismissButton: UIButton! {
        didSet {
            dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        }
    }

    var viewModel: BannerViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
        }
    }

    @IBAction func dismissButtonTapped(_ sender: UIButton) {
        print("dismiss")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = .color(.background)
        timeRemainingLabel.textColor = .color(.text, .weak)
        timeRemainingLabel.font = .systemFont(ofSize: 13)

        roundedBackgroundView.backgroundColor = .color(.background, .weak)
        roundedBackgroundView.layer.cornerRadius = .themeRadius12

        selectionStyle = .none
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

    }

    override func layoutSubviews() {
        super.layoutSubviews()

        roundedBackgroundView.gradientBorder(colors: [
                                                .init(red: 44, green: 220, blue: 203),
                                                .init(red: 75, green: 41, blue: 217)
                                             ],
                                             startPoint: .left,
                                             endPoint: .right,
                                             andRoundCornersWithRadius: .themeRadius12)
    }
}

public extension UIView {
    private static let kLayerNameGradientBorder = "GradientBorderLayer"

    func gradientBorder(
        width: CGFloat = 1,
        colors: [UIColor],
        startPoint: CGPoint.CoordinateSpace = .left,
        endPoint: CGPoint.CoordinateSpace = .right,
        andRoundCornersWithRadius cornerRadius: CGFloat = 0
    ) {
        let existingBorder = gradientBorderLayer()
        existingBorder?.removeFromSuperlayer()
        let border = CAGradientLayer()
        border.name = UIView.kLayerNameGradientBorder
        border.frame = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y,
            width: bounds.size.width + width,
            height: bounds.size.height + width
        )
        border.colors = colors.map { $0.cgColor }
        border.startPoint = startPoint.unitCoordinate
        border.endPoint = endPoint.unitCoordinate

        let mask = CAShapeLayer()
        let maskRect = CGRect(
            x: bounds.origin.x + width/2,
            y: bounds.origin.y + width/2,
            width: bounds.size.width - width,
            height: bounds.size.height - width
        )
        mask.path = UIBezierPath(
            roundedRect: maskRect,
            cornerRadius: cornerRadius
        ).cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = width

        border.mask = mask

//        let isAlreadyAdded = (existingBorder != nil)
//        if !isAlreadyAdded {
            layer.addSublayer(border)
//        }
    }

    private func gradientBorderLayer() -> CAGradientLayer? {
        let borderLayers = layer.sublayers?.filter {
            $0.name == UIView.kLayerNameGradientBorder
        }
        if borderLayers?.count ?? 0 > 1 {
            fatalError()
        }
        return borderLayers?.first as? CAGradientLayer
    }
}

public extension CGPoint {
    enum CoordinateSpace {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left

        var unitCoordinate: CGPoint {
            switch self {
            case .topLeft:
                return .init(x: 0, y: 0)
            case .top:
                return .init(x: 0.5, y: 0)
            case .topRight:
                return .init(x: 1, y: 0)
            case .right:
                return .init(x: 0, y: 0.5)
            case .bottomRight:
                return .init(x: 1, y: 1)
            case .bottom:
                return .init(x: 0.5, y: 1)
            case .bottomLeft:
                return .init(x: 0, y: 1)
            case .left:
                return .init(x: 1, y: 0.5)
            }
        }
    }
}
