//
//  RoutingTableEntry.m
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

#import <arpa/inet.h>
#import <netdb.h>
#import <net/if.h>
#import "route.h"

#import "RoutingTableEntry.h"

#define ASSERT_PRINTF(r)        NSCAssert(r >= 0, @"*printf() failed")
#define ASSERT_GETNAMEINFO(r)   NSCAssert(r == 0, @"getnameinfo() failed")

// adapted from: https://github.com/jianpx/ios-cabin

#define ROUNDUP(a) ((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint32_t) - 1))) : sizeof(uint32_t))

typedef union {
    uint32_t dummy;
    struct sockaddr u_sa;
    u_short u_data[128];
} sa_u;

static uint32_t RoutingTableEntryAddress4(NSString *string);
static NSData *RoutingTableEntryAddress6(NSString *string);
static NSString *RoutingTableEntryName(struct sockaddr *sa, struct sockaddr *mask, int flags);

#pragma mark -

@interface RoutingTableEntry ()

@property (nonatomic, assign) BOOL isIPv6;
@property (nonatomic, copy) NSString *network;
@property (nonatomic, assign) NSInteger prefix;
@property (nonatomic, copy) NSString *gateway;
@property (nonatomic, copy) NSString *networkInterface;

@end

@implementation RoutingTableEntry

- (instancetype)initWithNetwork:(NSString *)network prefix:(NSInteger)prefix gateway:(NSString *)gateway networkInterface:(NSString *)networkInterface
{
    if (!(self = [super init])) {
        return nil;
    }
    
    self.network = network;
    self.prefix = prefix;
    self.gateway = gateway;
    self.networkInterface = networkInterface;
    
    return self;
}

- (instancetype)initWithIPv4Network:(NSString *)network gateway:(NSString *)gateway networkInterface:(NSString *)networkInterface
{
    NSInteger prefix = 0;

    NSArray<NSString *> *networkComps = [network componentsSeparatedByString:@"/"];
    network = networkComps.firstObject;
    if (networkComps.count == 2) {
        prefix = [networkComps.lastObject integerValue];
        NSAssert(prefix >= 0 && prefix <= 32, @"IPv4 prefix must lie in [0..32]");
    } else {
        prefix = 32;
    }
    
    NSMutableArray<NSString *> *groups = [[network componentsSeparatedByString:@"."] mutableCopy];
    if (![network isEqualToString:@"default"]) {
        if (prefix == 32) {
            prefix = 8 * groups.count;
        }
        for (NSInteger i = groups.count; i < 4; ++i) {
            [groups addObject:@"0"];
        }
        network = [groups componentsJoinedByString:@"."];
    }

    if (!(self = [self initWithNetwork:network prefix:prefix gateway:gateway networkInterface:networkInterface])) {
        return nil;
    }
    self.isIPv6 = NO;
    return self;
}

- (instancetype)initWithIPv6Network:(NSString *)network gateway:(NSString *)gateway networkInterface:(NSString *)networkInterface
{
    NSInteger prefix = 0;

    NSArray<NSString *> *networkComps = [network componentsSeparatedByString:@"/"];
    network = networkComps.firstObject;
    if (networkComps.count == 2) {
        prefix = [networkComps.lastObject integerValue];
        NSAssert(prefix >= 0 && prefix <= 128, @"IPv6 prefix must lie in [0..128]");
    } else {
        prefix = 128;
    }
    network = [[network componentsSeparatedByString:@"%"] firstObject];
    gateway = [[gateway componentsSeparatedByString:@"%"] firstObject];

    if (!(self = [self initWithNetwork:network prefix:prefix gateway:gateway networkInterface:networkInterface])) {
        return nil;
    }
    self.isIPv6 = YES;
    return self;
}

- (instancetype)initWithRTM:(const struct rt_msghdr2 *)rtm
{
    NSParameterAssert(rtm);
    
    NSString *network;
    NSString *gateway;
    NSString *networkInterface;
    
    struct sockaddr *rti_info[RTAX_MAX];
    struct sockaddr *sa = (struct sockaddr *)(rtm + 1);
    for (int i = 0; i < RTAX_MAX; ++i) {
        if (rtm->rtm_addrs & (1 << i)) {
            rti_info[i] = sa;
            sa = (struct sockaddr *)(ROUNDUP(sa->sa_len) + (char *)sa);
        } else {
            rti_info[i] = NULL;
        }
    }
    
    // network
    sa_u destinationStruct, destinationNetmask;
    bzero(&destinationStruct, sizeof(destinationStruct));
    if (rtm->rtm_addrs & RTA_DST) {
        bcopy(rti_info[RTAX_DST], &destinationStruct, rti_info[RTAX_DST]->sa_len);
    }
    bzero(&destinationNetmask, sizeof(destinationNetmask));
    if (rtm->rtm_addrs & RTA_NETMASK) {
        bcopy(rti_info[RTAX_NETMASK], &destinationNetmask, rti_info[RTAX_NETMASK]->sa_len);
    }
    network = RoutingTableEntryName(&destinationStruct.u_sa, &destinationNetmask.u_sa, rtm->rtm_flags);
    
    // gateway
    sa_u gatewayStruct;
    bzero(&gatewayStruct, sizeof(gatewayStruct));
    if (rtm->rtm_addrs & RTA_GATEWAY) {
        bcopy(rti_info[RTAX_GATEWAY], &gatewayStruct, rti_info[RTAX_GATEWAY]->sa_len);
    }
    gateway = RoutingTableEntryName(rti_info[RTAX_GATEWAY], NULL, RTF_HOST);
    
    // network interface
    char networkInterfaceStr[IF_NAMESIZE];
    const char *networkInterfaceName = if_indextoname(rtm->rtm_index, networkInterfaceStr);
    if (networkInterfaceName) {
        networkInterface = [NSString stringWithCString:networkInterfaceName encoding:NSASCIIStringEncoding];
    }
    
    if (rti_info[RTAX_DST]->sa_family == AF_INET6) {
        return [self initWithIPv6Network:network gateway:gateway networkInterface:networkInterface];
    } else {
        return [self initWithIPv4Network:network gateway:gateway networkInterface:networkInterface];
    }
}

- (NSString *)networkMask
{
    struct in_addr mask;
    mask.s_addr = htonl(~((1 << (32 - self.prefix)) - 1));
    const char *address = inet_ntoa(mask);
    return [NSString stringWithCString:address encoding:NSASCIIStringEncoding];
}

- (BOOL)isDefault
{
    return [self.network isEqualToString:@"default"];
}

- (BOOL)matchesDestination:(NSString *)destination
{
    NSParameterAssert(destination);
    
    if ([self isDefault]) {
        return YES;
    }
    
    if (self.isIPv6) {
        NSData *networkAddress = RoutingTableEntryAddress6(self.network);
        NSData *destinationAddress = RoutingTableEntryAddress6(destination);
        if (!networkAddress || !destinationAddress) {
            return NO;
        }
        
//        NSLog(@"network:     %@ = %@", networkAddress, self.network);
//        NSLog(@"destination: %@ = %@", destinationAddress, destination);
        
        const uint8_t *networkPtr = networkAddress.bytes;
        const uint8_t *destinationPtr = destinationAddress.bytes;
        
        NSInteger leftBits = self.prefix;
//        NSLog(@"\tprefix = %u", (int)self.prefix);
        for (NSInteger i = 0; leftBits > 0; ++i) {
            uint8_t networkMask;
            if (leftBits >= 8) {
                networkMask = 0xff;
            } else {
                networkMask = ~((1 << (8 - leftBits)) - 1);
            }
//            NSLog(@"\tnetworkMask[%u] = %x", (int)i, networkMask);
            if (((networkPtr[i] ^ destinationPtr[i]) & networkMask) != 0) {
                return NO;
            }
            leftBits -= 8;
        }
//        NSLog(@"\tMATCH");
        return YES;
    }
    else {
        const uint32_t networkAddress = RoutingTableEntryAddress4(self.network);
        const uint32_t destinationAddress = RoutingTableEntryAddress4(destination);
        if ((networkAddress == UINT32_MAX) || (destinationAddress == UINT32_MAX)) {
            return NO;
        }
        const uint32_t networkMask = ~((1 << (32 - self.prefix)) - 1);
        
//        NSLog(@"network:     %x = %@", networkAddress, self.network);
//        NSLog(@"destination: %x = %@", destinationAddress, destination);
//        NSLog(@"mask:        %x", networkMask);
        
        return ((networkAddress ^ destinationAddress) & networkMask) == 0;
    }
}

- (nullable NSArray<RoutingTableEntry *> *)partitioned
{
    NSMutableArray<RoutingTableEntry *> *segments = [[NSMutableArray alloc] init];
    const int halfPrefix = (int)(self.prefix + 1);
    if (self.isIPv6) {
        if (self.prefix == 128) {
            NSLog(@"Can't partition single IPv6");
            return @[self, self];
        }
        
        struct in6_addr saddr1, saddr2;
        char addr[INET6_ADDRSTRLEN];
        NSData *addressData = RoutingTableEntryAddress6(self.network);
        if (!addressData) {
            return nil;
        }
        memcpy(&saddr1, addressData.bytes, addressData.length);
        NSMutableData *addressData2 = [addressData mutableCopy];
        
        uint8_t *addressBytes2 = (uint8_t *)addressData2.bytes;
        const uint8_t mask2 = 1 << ((8 - halfPrefix % 8) % 8);
        addressBytes2[(halfPrefix - 1) / 8] |= mask2;

        memcpy(&saddr2, addressData2.bytes, addressData2.length);

        inet_ntop(AF_INET6, &saddr1, addr, INET6_ADDRSTRLEN);
        NSString *network1 = [NSString stringWithFormat:@"%s/%d", addr, halfPrefix];
        inet_ntop(AF_INET6, &saddr2, addr, INET6_ADDRSTRLEN);
        NSString *network2 = [NSString stringWithFormat:@"%s/%d", addr, halfPrefix];

        [segments addObject:[[RoutingTableEntry alloc] initWithIPv6Network:network1 gateway:self.gateway networkInterface:self.networkInterface]];
        [segments addObject:[[RoutingTableEntry alloc] initWithIPv6Network:network2 gateway:self.gateway networkInterface:self.networkInterface]];
    } else {
        if (self.prefix == 32) {
            NSLog(@"Can't partition single IPv4");
            return @[self, self];
        }

        struct in_addr saddr1, saddr2;
        const uint32_t address = RoutingTableEntryAddress4(self.network);
        if (address == UINT32_MAX) {
            return nil;
        }
        saddr1.s_addr = htonl(address);
        saddr2.s_addr = htonl(address | (1 << (32 - halfPrefix)));

        // XXX: inet_ntoa returns pointer to static variable, copy before next call
        const char *address1 = inet_ntoa(saddr1);
        NSString *network1 = [NSString stringWithFormat:@"%s/%d", address1, halfPrefix];
        const char *address2 = inet_ntoa(saddr2);
        NSString *network2 = [NSString stringWithFormat:@"%s/%d", address2, halfPrefix];

        [segments addObject:[[RoutingTableEntry alloc] initWithIPv4Network:network1 gateway:self.gateway networkInterface:self.networkInterface]];
        [segments addObject:[[RoutingTableEntry alloc] initWithIPv4Network:network2 gateway:self.gateway networkInterface:self.networkInterface]];
    }
    return segments;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{%@/%ld -> %@ via %@}", self.network, self.prefix, self.gateway ?: @"nil", self.networkInterface];
}

@end

#pragma mark -

static char *netname(uint32_t in, uint32_t mask);
static char *netname6(struct sockaddr_in6 *sa6, struct sockaddr *sam);
static char *routename(uint32_t in);
static char *routename6(struct sockaddr_in6 *sa6);
static uint32_t forgemask(uint32_t a);
static void domask(char *dst, size_t dstsize, uint32_t addr, uint32_t mask);
static void trimdomain(char *cp);

static inline uint32_t RoutingTableEntryAddress4(NSString *string)
{
    struct in_addr addr;
    if (inet_pton(AF_INET, [string cStringUsingEncoding:NSASCIIStringEncoding], &addr) <= 0) {
        return UINT32_MAX;
    }
    return CFSwapInt32BigToHost(addr.s_addr);
}

static inline NSData *RoutingTableEntryAddress6(NSString *string)
{
    struct in6_addr addr;
    if (inet_pton(AF_INET6, [string cStringUsingEncoding:NSASCIIStringEncoding], &addr) <= 0) {
        return nil;
    }
    NSMutableData *data = [[NSMutableData alloc] initWithLength:16];
    memcpy(data.mutableBytes, (void *)&addr, data.length);
    return data;
}

static NSString *RoutingTableEntryName(struct sockaddr *sa, struct sockaddr *mask, int flags)
{
    char *cp = NULL;
    switch (sa->sa_family) {
        case AF_INET: {
            struct sockaddr_in *sin = (struct sockaddr_in *)sa;
            
            if ((sin->sin_addr.s_addr == INADDR_ANY) && mask && (ntohl(((struct sockaddr_in *)mask)->sin_addr.s_addr) == 0L || mask->sa_len == 0)) {
                cp = "default";
            } else if (flags & RTF_HOST) {
                cp = routename(sin->sin_addr.s_addr);
            } else if (mask) {
                cp = netname(sin->sin_addr.s_addr, ntohl(((struct sockaddr_in *)mask)->sin_addr.s_addr));
            } else {
                cp = netname(sin->sin_addr.s_addr, 0L);
            }
            break;
        }
        case AF_INET6: {
            struct sockaddr_in6 *sa6 = (struct sockaddr_in6 *)sa;
            struct in6_addr *in6 = &sa6->sin6_addr;
            
            /*
             * XXX: This is a special workaround for KAME kernels.
             * sin6_scope_id field of SA should be set in the future.
             */
            if (IN6_IS_ADDR_LINKLOCAL(in6) ||
                IN6_IS_ADDR_MC_NODELOCAL(in6) ||
                IN6_IS_ADDR_MC_LINKLOCAL(in6)) {

                /* XXX: override is ok? */
                sa6->sin6_scope_id = (u_int32_t)ntohs(*(u_short *)&in6->s6_addr[2]);
                *(u_short *)&in6->s6_addr[2] = 0;
            }
            
            if (flags & RTF_HOST) {
                cp = routename6(sa6);
            } else if (mask) {
                cp = netname6(sa6, mask);
            } else {
                cp = netname6(sa6, NULL);
            }
            break;
        }
        default:
            break;
    }
    if (!cp) {
        return nil;
    }
    return [NSString stringWithCString:cp encoding:NSASCIIStringEncoding];
}

char *routename(uint32_t in)
{
    static char line[MAXHOSTNAMELEN];
    
#define C(x)    ((x) & 0xff)
    in = ntohl(in);
    ASSERT_PRINTF(snprintf(line, sizeof(line), "%u.%u.%u.%u", C(in >> 24), C(in >> 16), C(in >> 8), C(in)));

    return (line);
}

char *routename6(struct sockaddr_in6 *sa6)
{
    static char line[MAXHOSTNAMELEN];
    int flag = NI_NUMERICHOST;
    /* use local variable for safety */
    struct sockaddr_in6 sa6_local = {sizeof(sa6_local), AF_INET6, };
    
    sa6_local.sin6_addr = sa6->sin6_addr;
    sa6_local.sin6_scope_id = sa6->sin6_scope_id;
    
    ASSERT_GETNAMEINFO(getnameinfo((struct sockaddr *)&sa6_local, sa6_local.sin6_len, line, sizeof(line), NULL, 0, flag));
    
    return line;
}
/*
 * Return the name of the network whose address is given.
 * The address is assumed to be that of a net or subnet, not a host.
 */
char *netname(uint32_t in, uint32_t mask)
{
    char *cp = 0;
    static char line[MAXHOSTNAMELEN];
    struct netent *np = 0;
    uint32_t net, omask, dmask;
    uint32_t i;
    
    i = ntohl(in);
    dmask = forgemask(i);
    omask = mask;
    //    if (!nflag && i) {
    if (i) {
        net = i & dmask;
        if (!(np = getnetbyaddr(i, AF_INET)) && net != i)
            np = getnetbyaddr(net, AF_INET);
        if (np) {
            cp = np->n_name;
            trimdomain(cp);
        }
    }
    if (cp) {
        strncpy(line, cp, sizeof(line) - 1);
    } else {
        switch (dmask) {
            case IN_CLASSA_NET:
                if ((i & IN_CLASSA_HOST) == 0) {
                    ASSERT_PRINTF(snprintf(line, sizeof(line), "%u", C(i >> 24)));
                    break;
                }
                /* FALLTHROUGH */
            case IN_CLASSB_NET:
                if ((i & IN_CLASSB_HOST) == 0) {
                    ASSERT_PRINTF(snprintf(line, sizeof(line), "%u.%u", C(i >> 24), C(i >> 16)));
                    break;
                }
                /* FALLTHROUGH */
            case IN_CLASSC_NET:
                if ((i & IN_CLASSC_HOST) == 0) {
                    ASSERT_PRINTF(snprintf(line, sizeof(line), "%u.%u.%u", C(i >> 24), C(i >> 16), C(i >> 8)));
                    break;
                }
                /* FALLTHROUGH */
            default:
                ASSERT_PRINTF(snprintf(line, sizeof(line), "%u.%u.%u.%u", C(i >> 24), C(i >> 16), C(i >> 8), C(i)));
                break;
        }
    }
    domask(line + strlen(line), sizeof(line) - strlen(line), i, omask);
    return (line);
}


char *netname6(struct sockaddr_in6 *sa6, struct sockaddr *sam)
{
    char host[MAXHOSTNAMELEN];
    static char line[MAXHOSTNAMELEN + 10];
    u_char *lim;
    int masklen, illegal = 0, flag = NI_NUMERICHOST;
    struct in6_addr *mask = sam ? &((struct sockaddr_in6 *)sam)->sin6_addr : 0;
    
    if (sam && sam->sa_len == 0) {
        masklen = 0;
    } else if (mask) {
        u_char *p = (u_char *)mask;
        for (masklen = 0, lim = p + 16; p < lim; p++) {
            switch (*p) {
                case 0xff:
                    masklen += 8;
                    break;
                case 0xfe:
                    masklen += 7;
                    break;
                case 0xfc:
                    masklen += 6;
                    break;
                case 0xf8:
                    masklen += 5;
                    break;
                case 0xf0:
                    masklen += 4;
                    break;
                case 0xe0:
                    masklen += 3;
                    break;
                case 0xc0:
                    masklen += 2;
                    break;
                case 0x80:
                    masklen += 1;
                    break;
                case 0x00:
                    break;
                default:
                    illegal ++;
                    break;
            }
        }
        if (illegal)
            fprintf(stderr, "illegal prefixlen\n");
    } else {
        masklen = 128;
    }
    if (masklen == 0 && IN6_IS_ADDR_UNSPECIFIED(&sa6->sin6_addr)) {
        return("default");
    }
    
    ASSERT_GETNAMEINFO(getnameinfo((struct sockaddr *)sa6, sa6->sin6_len, host, sizeof(host), NULL, 0, flag));
    
    if (masklen > 0) {
        ASSERT_PRINTF(sprintf(line, "%s/%u", host, masklen));
    } else {
        ASSERT_PRINTF(sprintf(line, "%s", host));
    }
    
    return line;
}

uint32_t forgemask(uint32_t a)
{
    uint32_t m;
    
    if (IN_CLASSA(a))
        m = IN_CLASSA_NET;
    else if (IN_CLASSB(a))
        m = IN_CLASSB_NET;
    else
        m = IN_CLASSC_NET;
    return (m);
}

void domask(char *dst, size_t dstsize, uint32_t addr, uint32_t mask)
{
    int b, i;
    
    if (!mask || (forgemask(addr) == mask)) {
        *dst = '\0';
        return;
    }
    i = 0;
    for (b = 0; b < 32; b++) {
        if (mask & (1 << b)) {
            int bb;
            
            i = b;
            for (bb = b+1; bb < 32; bb++)
                if (!(mask & (1 << bb))) {
                    i = -1;    /* noncontig */
                    break;
                }
            break;
        }
    }
    if (i == -1) {
        ASSERT_PRINTF(snprintf(dst, dstsize, "&0x%x", mask));
    } else {
        ASSERT_PRINTF(snprintf(dst, dstsize, "/%d", 32-i));
    }
}

void trimdomain(char *cp)
{
    static char domain[MAXHOSTNAMELEN + 1];
    static int first = 1;
    char *s;
    
    if (first) {
        first = 0;
        if (gethostname(domain, MAXHOSTNAMELEN) == 0 &&
            (s = strchr(domain, '.')))
            (void) strcpy(domain, s + 1);
        else
            domain[0] = 0;
    }
    
    if (domain[0]) {
        while ((cp = strchr(cp, '.'))) {
            if (!strcasecmp(cp + 1, domain)) {
                *cp = 0;        /* hit it */
                break;
            } else {
                cp++;
            }
        }
    }
}
