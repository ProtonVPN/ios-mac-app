//
//  WGConstants.swift
//  WireGuardiOS Extension
//
//  Created by Jaroslav on 2021-07-01.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

struct WGConstants {

    static var keychainAccessGroup: String = "\(Self.appIdentifierPrefix)prt.ProtonVPN"

    static var appIdentifierPrefix: String {
        return Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    }

    static var appGroupId: String {
        #if os(iOS)
        return AppConstants.AppGroups.main
        #elseif os(macOS)
        return "Not used on mac"
        #else
        #error("Unimplemented")
        #endif
    }

}
