//
//  VpnCredentials.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCoreNetworking
import Strings

public struct NetShieldFeatureSettings: Codable, Equatable {
    public let malware: Bool
    public let adsAndTrackers: Bool
    public let adultContent: Bool

    public init(malware: Bool, adsAndTrackers: Bool, adultContent: Bool) {
        self.malware = malware
        self.adsAndTrackers = adsAndTrackers
        self.adultContent = adultContent
    }
}

public struct VpnCredentials: Codable, Equatable, CustomStringConvertible {
    public let status: Int
    public let planTitle: String
    public let planName: String
    public let maxConnect: Int
    public let maxTier: Int
    public let services: Int?
    public let groupId: String
    public let name: String
    public let password: String
    public let delinquent: Int
    public let credit: Int
    public let currency: String
    public let hasPaymentMethod: Bool
    public let subscribed: Int?
    public let businessEvents: Bool
    public let isBusiness: Bool
    public let netshield: NetShieldFeatureSettings

    public var description: String {
        "Status: \(status)\n" +
            "Plan title: \(planTitle)\n" +
            "Plan name: \(planName)\n" +
            "Max connect: \(maxConnect)\n" +
            "Max tier: \(maxTier)\n" +
            "Services: \(services ?? -1)\n" +
            "Group ID: \(groupId)\n" +
            "Name: \(name)\n" +
            "Password: \(password)\n" +
            "Delinquent: \(delinquent)\n" +
            "Credit: \(credit) (in \(currency))" +
            "Has Payment Method: \(hasPaymentMethod)\n" +
            "Subscribed: \(String(describing: subscribed))" +
            "BusinessEvents: \(businessEvents)"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decode(Int.self, forKey: .status)
        self.planTitle = (try? container.decodeIfPresent(String.self, forKey: .planTitle)) ?? Localizable.freeTierPlanTitle
        self.planName = (try? container.decodeIfPresent(String.self, forKey: .planName)) ?? "free"
        self.maxConnect = try container.decode(Int.self, forKey: .maxConnect)
        self.maxTier = try container.decode(Int.self, forKey: .maxTier)
        self.services = try container.decode(Int.self, forKey: .services)
        self.groupId = try container.decode(String.self, forKey: .groupId)
        self.name = try container.decode(String.self, forKey: .name)
        self.password = try container.decode(String.self, forKey: .password)
        self.delinquent = try container.decode(Int.self, forKey: .delinquent)
        self.credit = try container.decode(Int.self, forKey: .credit)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.hasPaymentMethod = try container.decode(Bool.self, forKey: .hasPaymentMethod)
        self.subscribed = try container.decodeIfPresent(Int.self, forKey: .subscribed)
        self.businessEvents = try container.decode(Bool.self, forKey: .businessEvents)

        // These were added later, decoding is optional to avoid unnecessarily logging people out.
        // Remove optional decoding after this has been in prod for a year or so.
        self.isBusiness = (try? container.decodeIfPresent(Bool.self, forKey: .isBusiness)) ?? false
        self.netshield = (try? container.decodeIfPresent(NetShieldFeatureSettings.self, forKey: .netshield))
            ?? NetShieldFeatureSettings(malware: true, adsAndTrackers: true, adultContent: true)
    }

    public init(
        status: Int,
        planTitle: String,
        maxConnect: Int,
        maxTier: Int,
        services: Int?,
        groupId: String,
        name: String,
        password: String,
        delinquent: Int,
        credit: Int,
        currency: String,
        hasPaymentMethod: Bool,
        planName: String,
        subscribed: Int?,
        businessEvents: Bool,
        isBusiness: Bool,
        netshield: NetShieldFeatureSettings
    ) {
        self.status = status
        self.planTitle = planTitle
        self.maxConnect = maxConnect
        self.maxTier = maxTier
        self.services = services
        self.groupId = groupId
        self.name = name
        self.password = password
        self.delinquent = delinquent
        self.credit = credit
        self.currency = currency
        self.hasPaymentMethod = hasPaymentMethod
        self.planName = planName // Saving original string we got from API, because we need to know if it was null
        self.subscribed = subscribed
        self.businessEvents = businessEvents
        self.isBusiness = isBusiness
        self.netshield = netshield
    }

    public init(dic: JSONDictionary) throws {
        let vpnDic = try dic.jsonDictionaryOrThrow(key: "VPN")

        self.planTitle = vpnDic.string("PlanTitle") ?? Localizable.freeTierPlanTitle
        self.planName = vpnDic.string("PlanName") ?? "free"
        self.status = try vpnDic.intOrThrow(key: "Status")
        self.maxConnect = try vpnDic.intOrThrow(key: "MaxConnect")
        self.maxTier = vpnDic.int(key: "MaxTier") ?? .freeTier
        self.services = try dic.intOrThrow(key: "Services")
        self.groupId = try vpnDic.stringOrThrow(key: "GroupID")
        self.name = try vpnDic.stringOrThrow(key: "Name")
        self.password = try vpnDic.stringOrThrow(key: "Password")
        self.delinquent = try dic.intOrThrow(key: "Delinquent")
        self.credit = try dic.intOrThrow(key: "Credit")
        self.currency = try dic.stringOrThrow(key: "Currency")
        self.hasPaymentMethod = try dic.boolOrThrow(key: "HasPaymentMethod")
        self.subscribed = dic.int(key: "Subscribed")
        self.businessEvents = vpnDic.bool(key: "BusinessEvents", or: false)
        self.isBusiness = try vpnDic.boolOrThrow(key: "IsBusiness")
        let netshieldDic = try vpnDic.jsonDictionaryOrThrow(key: "NetShield")
        self.netshield = try NetShieldFeatureSettings(
            malware: netshieldDic.boolOrThrow(key: "Malware"),
            adsAndTrackers: netshieldDic.boolOrThrow(key: "AdsAndTrackers"),
            adultContent: netshieldDic.boolOrThrow(key: "AdultContent")
        )
    }

    /// Used for testing purposes.
    public var asDict: JSONDictionary {
        ([
            "VPN": [
                "PlanName": planName,
                "PlanTitle": planTitle,
                "Status": status,
                "MaxConnect": maxConnect,
                "MaxTier": maxTier,
                "GroupID": groupId,
                "Name": name,
                "Password": password,
                "BusinessEvents": businessEvents,
                "IsBusiness": isBusiness,
                "NetShield": [
                    "Malware": netshield.malware,
                    "AdsAndTrackers": netshield.adsAndTrackers,
                    "AdultContent": netshield.adultContent,
                ] as [String: Any],
            ] as [String: Any],
            "Services": services ?? -1,
            "Delinquent": delinquent,
            "Credit": credit,
            "Currency": currency,
            "HasPaymentMethod": hasPaymentMethod,
            "Subscribed": subscribed ?? 0,
        ] as [String: Any])
            .mapValues { $0 as AnyObject }
    }
}

public extension VpnCredentials {
    var isDelinquent: Bool {
        delinquent > 2
    }
}

/// Contains everything that VpnCredentials has, minus the username, password, group ID,
/// and expiration date/time.
/// This lets us avoid querying the keychain unnecessarily, since every query results in a synchronous
/// roundtrip to securityd.
public struct CachedVpnCredentials {
    public let status: Int
    public let planName: String
    public let planTitle: String
    public let maxConnect: Int
    public let maxTier: Int
    public let services: Int?
    public let delinquent: Int
    public let credit: Int
    public let currency: String
    public let hasPaymentMethod: Bool
    public let subscribed: Int?
    public let businessEvents: Bool
    public let isBusiness: Bool
    public let netshield: NetShieldFeatureSettings

    public var canUsePromoCode: Bool {
        !isDelinquent && !hasPaymentMethod && credit == 0 && subscribed == 0
    }
}

extension CachedVpnCredentials {
    init(credentials: VpnCredentials) {
        self.init(
            status: credentials.status,
            planName: credentials.planName,
            planTitle: credentials.planTitle,
            maxConnect: credentials.maxConnect,
            maxTier: credentials.maxTier,
            services: credentials.services,
            delinquent: credentials.delinquent,
            credit: credentials.credit,
            currency: credentials.currency,
            hasPaymentMethod: credentials.hasPaymentMethod,
            subscribed: credentials.subscribed,
            businessEvents: credentials.businessEvents,
            isBusiness: credentials.isBusiness,
            netshield: credentials.netshield
        )
    }
}

// MARK: - Checks performed on CachedVpnCredentials

public extension CachedVpnCredentials {
    var isDelinquent: Bool {
        delinquent > 2
    }
}
