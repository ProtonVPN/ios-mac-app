//
//  NetworkStatistics.swift
//  ProtonVPN - Created on 27.06.19.
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

struct Bitrate {
    var download: UInt32
    var upload: UInt32
}

class NetworkStatistics {
    
    private struct NetworkTraffic {
        var downloadCount: UInt32 = 0
        var uploadCount: UInt32 = 0
        
        mutating func updateCountsByAdding(_ statistics: NetworkTraffic) {
            downloadCount = UInt32((UInt64(downloadCount) + UInt64(statistics.downloadCount)) % UInt64(UInt32.max))
            uploadCount = UInt32((UInt64(uploadCount) + UInt64(statistics.uploadCount)) % UInt64(UInt32.max))
        }
    }
    
    private var timer: Timer! = nil
    private var timeInterval: TimeInterval = 1
    private var traffic: NetworkTraffic! = nil
    private var updateWithBitrate: ((Bitrate) -> Void)?
    
    init(with timeInterval: TimeInterval, and updateHandler: @escaping (Bitrate) -> Void) {
        self.timeInterval = timeInterval
        updateWithBitrate = updateHandler
        
        traffic = getTrafficStatistics()
        
        timer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector(updateBitrate), userInfo: nil, repeats: true)
        updateBitrate()
    }
    
    func stopGathering() {
        timer.invalidate()
    }
    
    @objc private func updateBitrate() {
        guard let updateWithBitrate = updateWithBitrate else { return }
        
        let latestTraffic = self.getTrafficStatistics()
        
        // usage can overflow
        let bitrate = Bitrate(download: UInt32(TimeInterval(latestTraffic.downloadCount >= self.traffic.downloadCount
                                                            ? latestTraffic.downloadCount - self.traffic.downloadCount
                                                            : latestTraffic.downloadCount)
                                                            / timeInterval),
                              upload: UInt32(TimeInterval(latestTraffic.uploadCount >= self.traffic.uploadCount
                                                          ? latestTraffic.uploadCount - self.traffic.uploadCount
                                                          : latestTraffic.uploadCount)
                                                          / timeInterval))
        
        self.traffic = latestTraffic
        
        updateWithBitrate(bitrate)
    }
    
    private func getTrafficStatistics() -> NetworkTraffic {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        var tempifaddr: UnsafeMutablePointer<ifaddrs>?
        var traffic = NetworkTraffic()
        
        guard getifaddrs(&ifaddr) == 0 else { return traffic }
        tempifaddr = ifaddr
        while let addr = tempifaddr {
            if let traf = trafficStatistics(from: addr) {
                traffic.updateCountsByAdding(traf)
            }
            
            tempifaddr = addr.pointee.ifa_next
        }
        
        freeifaddrs(ifaddr)
        return traffic
    }
    
    private func trafficStatistics(from trafficPointer: UnsafeMutablePointer<ifaddrs>) -> NetworkTraffic? {
        let addr = trafficPointer.pointee.ifa_addr.pointee
        guard addr.sa_family == UInt8(AF_LINK) else { return nil }
        
        let wwanInterfacePrefix = "pdp_ip"
        let wifiInterfacePrefix = "en"
        let name: String! = String(cString: trafficPointer.pointee.ifa_name)
        var networkData: UnsafeMutablePointer<if_data>?
        var traffic = NetworkTraffic()
        
        if name.hasPrefix(wifiInterfacePrefix) || name.hasPrefix(wwanInterfacePrefix) {
            networkData = unsafeBitCast(trafficPointer.pointee.ifa_data, to: UnsafeMutablePointer<if_data>.self)
            if let data = networkData {
                traffic.uploadCount += data.pointee.ifi_obytes
                traffic.downloadCount += data.pointee.ifi_ibytes
            }
            
        }
        
        return traffic
    }
}
