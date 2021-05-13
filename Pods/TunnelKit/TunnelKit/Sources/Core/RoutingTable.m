//
//  RoutingTable.m
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

#import <sys/sysctl.h>
#import "route.h"

#import "RoutingTable.h"
#import "Allocation.h"

// adapted from: https://github.com/jianpx/ios-cabin

@interface RoutingTableEntry ()

- (instancetype)initWithRTM:(const struct rt_msghdr2 *)rtm;

@end

#pragma mark -

@interface RoutingTable ()

@property (nonatomic, strong) NSArray<RoutingTableEntry *> *ipv4;
@property (nonatomic, strong) NSArray<RoutingTableEntry *> *ipv6;

@end

@implementation RoutingTable
    
- (instancetype)init
{
    if (!(self = [super init])) {
        return nil;
    }

    int mib[] = { CTL_NET, PF_ROUTE, 0, 0, NET_RT_DUMP2, 0 };
    const int mibLen = sizeof(mib) / sizeof(int);
    size_t len;
    if (sysctl(mib, mibLen, NULL, &len, NULL, 0) || (len <= 0)) {
        return nil;
    }

    char *buf = allocate_safely(len);
    if (!buf) {
        return nil;
    }
    if (sysctl(mib, mibLen, buf, &len, NULL, 0)) {
        free(buf);
        return nil;
    }

    NSMutableArray<RoutingTableEntry *> *entries4 = [[NSMutableArray alloc] init];
    NSMutableArray<RoutingTableEntry *> *entries6 = [[NSMutableArray alloc] init];

    for (const char *ptr = buf; ptr < buf + len;) {
        const struct rt_msghdr2 *rtm = (struct rt_msghdr2 *)ptr;

        if (rtm->rtm_addrs & RTA_DST) {
            struct sockaddr *dst_sa = (struct sockaddr *)(rtm + 1); // XXX: why +1 ?!?

            if (((dst_sa->sa_family == AF_INET) || (dst_sa->sa_family == AF_INET6)) && !((rtm->rtm_flags & RTF_WASCLONED) && (rtm->rtm_parentflags & RTF_PRCLONING))) {
                RoutingTableEntry *entry = [[RoutingTableEntry alloc] initWithRTM:rtm];
                if (!entry) {
                    continue;
                }
                if (dst_sa->sa_family == AF_INET) {
                    [entries4 addObject:entry];
                } else if (dst_sa->sa_family == AF_INET6) {
                    [entries6 addObject:entry];
                }
            }
        }
        
        ptr += rtm->rtm_msglen;
    }

    free(buf);
    
    self.ipv4 = entries4;
    self.ipv6 = entries6;

    return self;
}

- (RoutingTableEntry *)defaultGateway4
{
    for (RoutingTableEntry *entry in self.ipv4) {
        if ([entry isDefault]) {
            return entry;
        }
    }
    return nil;
}

- (RoutingTableEntry *)defaultGateway6
{
    for (RoutingTableEntry *entry in self.ipv6) {
        if ([entry isDefault]) {
            return entry;
        }
    }
    return nil;
}

- (RoutingTableEntry *)broadestRoute4MatchingDestination:(NSString *)destination
{
    RoutingTableEntry *defaultRoute;
    RoutingTableEntry *minRoute;
    NSInteger minPrefix = 32 + 1;
    for (RoutingTableEntry *route in self.ipv4) {
        if ([route isDefault]) { // leave last
            defaultRoute = route;
            continue;
        }
        if ([route matchesDestination:destination] && route.prefix < minPrefix) {
            minRoute = route;
            minPrefix = route.prefix;
        }
    }
    return minRoute ?: defaultRoute;
}

- (RoutingTableEntry *)broadestRoute6MatchingDestination:(NSString *)destination
{
    RoutingTableEntry *defaultRoute;
    RoutingTableEntry *minRoute;
    NSInteger minPrefix = 128 + 1;
    for (RoutingTableEntry *route in self.ipv6) {
        if ([route isDefault]) { // leave last
            defaultRoute = route;
            continue;
        }
        if ([route matchesDestination:destination] && route.prefix < minPrefix) {
            minRoute = route;
            minPrefix = route.prefix;
        }
    }
    return minRoute ?: defaultRoute;
}

@end
