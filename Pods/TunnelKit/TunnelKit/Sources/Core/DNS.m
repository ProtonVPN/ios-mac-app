//
//  DNS.m
//  TunnelKit
//
//  Created by Davide De Rosa on 4/25/19.
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

// adapted from: https://stackoverflow.com/questions/31256024/get-dns-server-ip-from-iphone-settings

#import <resolv.h>
#import <netdb.h>

#import "DNS.h"

@implementation DNS {
    res_state _state;
}

- (instancetype)init
{
    if (self = [super init]) {
        _state = malloc(sizeof(struct __res_state));
        if (EXIT_SUCCESS != res_ninit(_state)) {
            free(_state);
            return nil;
        }
    }
    return self;
}
    
- (void)dealloc
{
    res_ndestroy(_state);
    free(_state);
}
    
- (NSArray<NSString *> *)systemServers
{
    NSMutableArray *addresses = [[NSMutableArray alloc] init];
    
    union res_sockaddr_union servers[NI_MAXSERV];
    const int found = res_9_getservers(_state, servers, NI_MAXSERV);
    char hostBuffer[NI_MAXHOST];

    for (int i = 0; i < found; ++i) {
        union res_sockaddr_union s = servers[i];
        if (s.sin.sin_len <= 0) {
            continue;
        }
        if (EXIT_SUCCESS == getnameinfo((struct sockaddr *)&s.sin,  // Pointer to your struct sockaddr
                                        (socklen_t)s.sin.sin_len,   // Size of this struct
                                        (char *)&hostBuffer,        // Pointer to hostname string
                                        sizeof(hostBuffer),         // Size of this string
                                        nil,                        // Pointer to service name string
                                        0,                          // Size of this string
                                        NI_NUMERICHOST)) {          // Flags given
            [addresses addObject:[NSString stringWithUTF8String:hostBuffer]];
        }
    }
    
    return addresses;
}

@end
