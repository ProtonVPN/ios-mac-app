//
//  RoutingTable.h
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

#import "RoutingTableEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface RoutingTable : NSObject

- (NSArray<RoutingTableEntry *> *)ipv4;
- (NSArray<RoutingTableEntry *> *)ipv6;
- (nullable RoutingTableEntry *)defaultGateway4;
- (nullable RoutingTableEntry *)defaultGateway6;
- (nullable RoutingTableEntry *)broadestRoute4MatchingDestination:(NSString *)destination;
- (nullable RoutingTableEntry *)broadestRoute6MatchingDestination:(NSString *)destination;

@end

NS_ASSUME_NONNULL_END
