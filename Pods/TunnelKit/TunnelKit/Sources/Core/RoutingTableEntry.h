//
//  RoutingTableEntry.h
//  TunnelKit
//
//  Created by Davide De Rosa on 4/30/19.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RoutingTableEntry : NSObject

- (instancetype)initWithIPv4Network:(NSString *)network gateway:(nullable NSString *)gateway networkInterface:(NSString *)networkInterface;
- (instancetype)initWithIPv6Network:(NSString *)network gateway:(nullable NSString *)gateway networkInterface:(NSString *)networkInterface;

- (BOOL)isIPv6;
- (NSString *)network;
- (NSInteger)prefix;
- (nullable NSString *)networkMask; // nil if IPv6
- (nullable NSString *)gateway;
- (NSString *)networkInterface;

- (BOOL)isDefault;
- (BOOL)matchesDestination:(NSString *)destination;
- (nullable NSArray<RoutingTableEntry *> *)partitioned;

@end

NS_ASSUME_NONNULL_END
