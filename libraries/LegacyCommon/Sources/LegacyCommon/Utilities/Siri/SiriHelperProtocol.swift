//
//  SiriHelper.swift
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
import Intents
import Dependencies

public protocol SiriHelperFactory {
    func makeSiriHelper() -> SiriHelperProtocol
}

public protocol SiriHelperProtocol {
    func donateQuickConnect()
    func donateDisconnect()
}

extension DependencyValues {
    public var siriHelper: @Sendable () -> SiriHelperProtocol {
        get { self[SiriHelperKey.self] }
        set { self[SiriHelperKey.self] = newValue }
    }
}

private enum SiriHelperKey: DependencyKey {
    static let liveValue: @Sendable () -> SiriHelperProtocol = {
        // Can be changed to `return SiriHelper()` when getting rid of current Dependency container
        return Container.sharedContainer.makeSiriHelper()
    }
}

public class SiriHelper: SiriHelperProtocol {
    public static var quickConnectIntent: INIntent?
    public static var disconnectIntent: INIntent?

    public init() {
    }

    public func donateQuickConnect() {
        #if os(iOS)
        guard let quickConnectIntent = Self.quickConnectIntent else { return }

        let interaction = INInteraction(intent: quickConnectIntent, response: nil)
        interaction.donate(completion: {error in
            if let error = error {
                log.error("Error on QuickConnectIntent donation: \(error)", category: .app)
            }
        })
        #endif
    }
    
    public func donateDisconnect() {
        #if os(iOS)
        guard let disconnectIntent = Self.disconnectIntent else { return }

        let interaction = INInteraction(intent: disconnectIntent, response: nil)
        interaction.donate(completion: {error in
            if let error = error {
                log.error("Error on DisconnectIntent donation: \(error)", category: .app)
            }
        })
        #endif
    }
    
}
