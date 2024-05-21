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

import UIKit
import LegacyCommon

final class ColorPickerViewModel: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
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
        return 12
    }

    var interitemSpacing: CGFloat {
        return 24
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let item = collectionView.dequeueReusableCell(withReuseIdentifier: ColorPickerItem.identifier, for: indexPath)  as? ColorPickerItem {
            item.color = colorAt(index: indexPath.row)
            return item
        }
        return UICollectionViewCell()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cellHeight, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return interitemSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return interitemSpacing
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedColorIndex = indexPath.row
        colorChanged?()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        collectionView.selectItem(at: IndexPath(row: selectedColorIndex, section: 0), animated: false, scrollPosition: .top)
    }
    
    private let colors: [UIColor]
    
    var selectedColorIndex: Int!
    var selectedColor: UIColor {
        return colorAt(index: selectedColorIndex)
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
        guard let newColor = newColor else {
            selectRandom()
            return
        }
        
        if let index = colors.enumerated().first(where: { (index, color) -> Bool in
            color == newColor
        })?.offset {
            selectedColorIndex = index
        } else {
            selectedColorIndex = 0
        }
    }

    func colorAt(index: Int) -> UIColor {
        return colors[index]
    }
}
