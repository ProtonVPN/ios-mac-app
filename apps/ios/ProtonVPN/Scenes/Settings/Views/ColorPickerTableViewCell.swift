//
//  ColorPickerTableViewCell.swift
//  ProtonVPN - Created on 20.08.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import UIKit

class ColorPickerTableViewCell: UITableViewCell {

    @IBOutlet weak var collectionView: UICollectionView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        backgroundColor = .protonGrey()
        collectionView.backgroundColor = .protonGrey()
        
        collectionView.register(ColorPickerItem.nib,
                                forCellWithReuseIdentifier: ColorPickerItem.identifier)
    }
    
}
