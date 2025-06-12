//
//  ColorPickerViewModel.swift
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

import LegacyCommon
import UIKit

class ColorPickerViewModel: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    var colorChanged: (() -> Void)?

    var cellHeight: CGFloat {
        var d: CGFloat = 40
        if UIDevice.current.screenType == .iPhones_5_5s_5c_SE {
            d *= 0.8
        }
        return d
    }

    var height: CGFloat {
        let numberOfLines: CGFloat = UIDevice.current.isIpad ? 1 : 2
        return (cellHeight + interitemSpacing) * numberOfLines + inset
    }

    var inset: CGFloat {
        12
    }

    var interitemSpacing: CGFloat {
        24
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        colors.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let item = collectionView.dequeueReusableCell(withReuseIdentifier: ColorPickerItem.identifier, for: indexPath) as? ColorPickerItem {
            item.color = colorAt(index: indexPath.row)
            return item
        }
        return UICollectionViewCell()
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        CGSize(width: cellHeight, height: cellHeight)
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        interitemSpacing
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        interitemSpacing
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, insetForSectionAt _: Int) -> UIEdgeInsets {
        UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedColorIndex = indexPath.row
        colorChanged?()
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt _: IndexPath) {
        collectionView.selectItem(at: IndexPath(row: selectedColorIndex, section: 0), animated: false, scrollPosition: .top)
    }

    private let colors: [UIColor]

    var selectedColorIndex: Int!
    var selectedColor: UIColor {
        colorAt(index: selectedColorIndex)
    }

    init(with color: UIColor? = nil) {
        colors = ProfileConstants.profileColors

        super.init()

        select(color: color)
    }

    func selectRandom() {
        selectedColorIndex = Int(arc4random_uniform(UInt32(colors.count))) // swiftlint:disable:this legacy_random
    }

    func select(color newColor: UIColor?) {
        guard let newColor else {
            selectRandom()
            return
        }

        if let index = colors.enumerated().first(where: { _, color -> Bool in
            color.hexRepresentation == newColor.hexRepresentation
        })?.offset {
            selectedColorIndex = index
        } else {
            selectedColorIndex = 0
        }
    }

    func select(color index: Int) {
        if index >= 0, index < colors.count {
            selectedColorIndex = index
        }
    }

    func colorAt(index: Int) -> UIColor {
        colors[index]
    }
}
