//
//  PacketStream.m
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

#import "PacketStream.h"

static const NSInteger PacketStreamHeaderLength = sizeof(uint16_t);

@implementation PacketStream

+ (NSArray<NSData *> *)packetsFromStream:(NSData *)stream until:(NSInteger *)until
{
    NSInteger ni = 0;
    NSMutableArray<NSData *> *parsed = [[NSMutableArray alloc] init];

    while (ni + PacketStreamHeaderLength <= stream.length) {
        const NSInteger packlen = CFSwapInt16BigToHost(*(uint16_t *)(stream.bytes + ni));
        const NSInteger start = ni + PacketStreamHeaderLength;
        const NSInteger end = start + packlen;
        if (end > stream.length) {
            break;
        }
        NSData *packet = [stream subdataWithRange:NSMakeRange(start, packlen)];
        [parsed addObject:packet];
        ni = end;
    }
    if (until) {
        *until = ni;
    }
    return parsed;
}

+ (NSData *)streamFromPacket:(NSData *)packet
{
    NSMutableData *raw = [[NSMutableData alloc] initWithLength:(PacketStreamHeaderLength + packet.length)];

    uint8_t *ptr = raw.mutableBytes;
    *(uint16_t *)ptr = CFSwapInt16HostToBig(packet.length);
    ptr += PacketStreamHeaderLength;
    memcpy(ptr, packet.bytes, packet.length);
    
    return raw;
}

+ (NSData *)streamFromPackets:(NSArray<NSData *> *)packets;
{
    NSInteger streamLength = 0;
    for (NSData *p in packets) {
        streamLength += PacketStreamHeaderLength + p.length;
    }

    NSMutableData *raw = [[NSMutableData alloc] initWithLength:streamLength];
    uint8_t *ptr = raw.mutableBytes;
    for (NSData *packet in packets) {
        *(uint16_t *)ptr = CFSwapInt16HostToBig(packet.length);
        ptr += PacketStreamHeaderLength;
        memcpy(ptr, packet.bytes, packet.length);
        ptr += packet.length;
    }
    return raw;
}

@end
