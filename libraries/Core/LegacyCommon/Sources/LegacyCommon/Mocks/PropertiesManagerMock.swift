//
//  PropertiesManagerMock.swift
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

#if DEBUG
    import CommonNetworking
    import Domain
    import Foundation
    import ProtonCoreDataModel
    import ProtonCoreLogin
    import ProtonCoreServices
    import Sharing
    import VPNAppCore
    import VPNShared

    public class PropertiesManagerMock: PropertiesManagerProtocol {
        public var isSubsequentLaunch: Bool = false
        public var firstLaunchReported: Bool = false
        public var showWhatsNewModal: Bool = false

        private let queue = DispatchQueue(label: "ch.proton.test.mock.sync.properties")

        public var onAlternativeRoutingChange: ((Bool) -> Void)?

        var autoConnect: (enabled: Bool, profileId: String?) = (true, nil)
        public func getAutoConnect(for _: String) -> (enabled: Bool, profileId: String?) {
            autoConnect
        }

        public func setAutoConnect(for _: String, enabled: Bool, profileId: String?) {
            autoConnect = (enabled, profileId)
        }

        public var hasConnected: Bool = false

        public var blockOneTimeAnnouncement: Bool = false
        public var lastPreparedServer: ServerModel?

        var lastUserAccountPlan: String?
        public func getLastAccountPlan(for _: String) -> String? {
            lastUserAccountPlan
        }

        public func setLastAccountPlan(for _: String, plan: String?) {
            lastUserAccountPlan = plan
        }

        public var quickConnect: String?
        public func getQuickConnect(for _: String) -> String? {
            quickConnect
        }

        public func setQuickConnect(for _: String, quickConnect: String?) {
            self.quickConnect = quickConnect
        }

        public var userLocation: UserLocation? {
            didSet {
                AppEvent.userIp.post(userLocation)
            }
        }

        public var userDataDisclaimerAgreed: Bool = false

        public var trialWelcomed: Bool = false
        public var warnedTrialExpiring: Bool = false
        public var warnedTrialExpired: Bool = false
        public var reportBugEmail: String?
        public var discourageSecureCore: Bool = false
        public var ratingSettings: RatingSettings = .init()
        public var serverChangeConfig: ServerChangeConfig = .init()

        #if os(macOS)
            public var forceExtensionUpgrade: Bool = false
        #endif

        public var apiEndpoint: String?
        public var lastAppVersion = "0.0.0"

        public var maintenanceServerRefreshIntereval: Int = 1
        public var vpnAcceleratorEnabled: Bool = false

        public var portForwarding: Bool = false

        public var humanValidationFailed: Bool = false
        public var alternativeRouting: Bool = false {
            didSet {
                onAlternativeRoutingChange?(alternativeRouting)
            }
        }

        public var _streamingServices: StreamingDictServices = [:]
        public var streamingServices: StreamingDictServices {
            get { queue.sync { _streamingServices } }
            set { queue.sync { _streamingServices = newValue } }
        }

        public var userAccountRecovery: ProtonCoreDataModel.AccountRecovery?
        public var userRole: UserRole = .noOrganization
        public var excludeLocalNetworks: Bool = true

        public var userInfo: UserInfo?
        public var userSettings: UserSettings?

        public var _streamingResourcesUrl: String?
        public var streamingResourcesUrl: String? {
            get { queue.sync { _streamingResourcesUrl } }
            set { queue.sync { _streamingResourcesUrl = newValue } }
        }

        public var didShowDeprecationWarningForOSVersion: String?

        public var atlasSecret: String?
        public var atlasSecretFetchURLString: String?
        public var featureFlagOverrides: [String: Bool]?
        public var localValuesOverrides: [String: String]?

        private var customBools: [String: Bool] = [:]
        private var defaultCustomBoolValue = false

        public func getValue(forKey key: String) -> Bool {
            customBools[key] ?? defaultCustomBoolValue
        }

        public func setValue(_ value: Bool, forKey key: String) {
            customBools[key] = value
        }

        public init() {}

        public func logoutCleanup() {
            hasConnected = false
            @Shared(.secureCoreToggle) var secureCoreToggle
            $secureCoreToggle.withLock { $0 = false }
            reportBugEmail = nil
        }

        public func logCurrentState() {}
    }
#endif
