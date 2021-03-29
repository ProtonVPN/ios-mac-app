//
//  SignUpSmsCountryCodeViewModel.swift
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

import Foundation

protocol SmsCountryCodeViewModelFactory {
    func makeSmsCountryCodeViewModel(with callback: @escaping (PhoneCountryCode) -> Void) -> SmsCountryCodeViewModel
}

extension DependencyContainer: SmsCountryCodeViewModelFactory {
    func makeSmsCountryCodeViewModel(with callback: @escaping (PhoneCountryCode) -> Void) -> SmsCountryCodeViewModel {
        return SmsCountryCodeViewModel(with: callback)
    }
}

class SmsCountryCodeViewModel {
    
    private let phoneCountryCodes: [PhoneCountryCode]
    private let selectionCallback: (PhoneCountryCode) -> Void
    
    private var searchedCountryCodes: [PhoneCountryCode]
    
    init(with selectionCallback: @escaping (PhoneCountryCode) -> Void) {
        phoneCountryCodes = PhoneCountryCode.getPhoneCountryCodes()
        self.selectionCallback = selectionCallback
        searchedCountryCodes = phoneCountryCodes
    }
    
    func numberOfRows() -> Int {
        return searchedCountryCodes.count
    }
    
    func cellModel(for row: Int) -> PhoneCountryCodeViewModel {
        let cellModel = PhoneCountryCodeViewModel(phoneCountryCode: searchedCountryCodes[row])
        return cellModel
    }
    
    func updateSearchResults(_ searchString: String?) {
        guard let searchString = searchString, !searchString.isEmpty else {
            searchedCountryCodes = phoneCountryCodes
            return
        }
        
        searchedCountryCodes = phoneCountryCodes.filter { (phoneCode) -> Bool in
            var phoneCodeSearchString = searchString
            phoneCodeSearchString.removeAll(where: { (character) -> Bool in
                return character == "+"
            })
            return phoneCode.localizedCountryName.starts(with: searchString) || "\(phoneCode.phoneCode)".starts(with: phoneCodeSearchString)
        }
    }
    
    func selectRow(_ row: Int) {
        selectionCallback(searchedCountryCodes[row])
    }
}
