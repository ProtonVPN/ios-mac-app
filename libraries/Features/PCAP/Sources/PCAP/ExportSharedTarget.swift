//
//  Created on 2026-02-05.
//
//  Copyright (c) 2025 Proton AG
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

import PCAPShared

public typealias CaptureVPNSessionFeature = PCAPShared.CaptureVPNSessionFeature
public typealias SessionCapturedFeature = PCAPShared.SessionCapturedFeature

#if canImport(PCAP_macOS)

    import PCAP_macOS

#endif

#if canImport(PCAP_iOS)
    import PCAP_iOS

    public typealias CaptureVPNSessionView = PCAP_iOS.CaptureVPNSessionView
    public typealias SessionCapturedSheetView = PCAP_iOS.SessionCapturedSheetView

#endif
