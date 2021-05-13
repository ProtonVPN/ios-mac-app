//
//  DataPath.m
//  TunnelKit
//
//  Created by Davide De Rosa on 3/2/17.
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
//  This file incorporates work covered by the following copyright and
//  permission notice:
//
//      Copyright (c) 2018-Present Private Internet Access
//
//      Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//      The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <arpa/inet.h>

#import "DataPath.h"
#import "DataPathCrypto.h"
#import "PacketMacros.h"
#import "MSS.h"
#import "ReplayProtector.h"
#import "LZO.h"
#import "Allocation.h"
#import "Errors.h"

#define DataPathByteAlignment   16

@interface DataPath ()

@property (nonatomic, strong) id<DataPathEncrypter> encrypter;
@property (nonatomic, strong) id<DataPathDecrypter> decrypter;
@property (nonatomic, assign) int packetCapacity;

// outbound -> UDP
@property (nonatomic, strong) NSMutableArray *outPackets;
@property (nonatomic, assign) uint32_t outPacketId;
@property (nonatomic, unsafe_unretained) uint8_t *encBuffer;
@property (nonatomic, assign) int encBufferCapacity;

// inbound -> TUN
@property (nonatomic, strong) NSMutableArray *inPackets;
@property (nonatomic, unsafe_unretained) uint8_t *decBuffer;
@property (nonatomic, assign) int decBufferCapacity;
@property (nonatomic, strong) ReplayProtector *inReplay;

@property (nonatomic, copy) DataPathAssembleBlock assemblePayloadBlock;
@property (nonatomic, copy) DataPathParseBlock parsePayloadBlock;
@property (nonatomic, strong) id<LZO> lzo;

@end

@implementation DataPath

+ (uint8_t *)alignedPointer:(uint8_t *)pointer
{
    uint8_t *stack = pointer;
    uintptr_t addr = (uintptr_t)stack;
    if (addr % DataPathByteAlignment != 0) {
        addr += DataPathByteAlignment - addr % DataPathByteAlignment;
    }
    return (uint8_t *)addr;
}

- (instancetype)initWithEncrypter:(id<DataPathEncrypter>)encrypter
                        decrypter:(id<DataPathDecrypter>)decrypter
                           peerId:(uint32_t)peerId
               compressionFraming:(CompressionFramingNative)compressionFraming
             compressionAlgorithm:(CompressionAlgorithmNative)compressionAlgorithm
                       maxPackets:(NSInteger)maxPackets
             usesReplayProtection:(BOOL)usesReplayProtection
{
    NSParameterAssert(encrypter);
    NSParameterAssert(decrypter);
    NSParameterAssert(maxPackets > 0);
    
    peerId &= 0xffffff;
    
    if ((self = [super init])) {
        self.encrypter = encrypter;
        self.decrypter = decrypter;
        
        self.maxPacketId = UINT32_MAX - 10000;
        self.outPackets = [[NSMutableArray alloc] initWithCapacity:maxPackets];
        self.outPacketId = 0;
        self.encBufferCapacity = 65000;
        self.encBuffer = allocate_safely(self.encBufferCapacity);
        
        self.inPackets = [[NSMutableArray alloc] initWithCapacity:maxPackets];
        self.decBufferCapacity = 65000;
        self.decBuffer = allocate_safely(self.decBufferCapacity);
        if (usesReplayProtection) {
            self.inReplay = [[ReplayProtector alloc] init];
        }

        [self.encrypter setPeerId:peerId];
        [self.decrypter setPeerId:peerId];
        [self setCompressionFraming:compressionFraming];
        
        if (LZOIsSupported() && (compressionAlgorithm == CompressionAlgorithmNativeLZO)) {
            self.lzo = LZOCreate();
        }
    }
    return self;
}

- (void)dealloc
{
    bzero(self.encBuffer, self.encBufferCapacity);
    bzero(self.decBuffer, self.decBufferCapacity);
    free(self.encBuffer);
    free(self.decBuffer);
}

- (void)adjustEncBufferToPacketSize:(int)size
{
    const int neededCapacity = DataPathByteAlignment + (int)[self.encrypter encryptionCapacityWithLength:size];
    if (self.encBufferCapacity >= neededCapacity) {
        return;
    }
    bzero(self.encBuffer, self.encBufferCapacity);
    free(self.encBuffer);
    self.encBufferCapacity = neededCapacity;
    self.encBuffer = allocate_safely(self.encBufferCapacity);
}

- (void)adjustDecBufferToPacketSize:(int)size
{
    const int neededCapacity = DataPathByteAlignment + (int)[self.decrypter encryptionCapacityWithLength:size];
    if (self.decBufferCapacity >= neededCapacity) {
        return;
    }
    bzero(self.decBuffer, self.decBufferCapacity);
    free(self.decBuffer);
    self.decBufferCapacity = neededCapacity;
    self.decBuffer = allocate_safely(self.decBufferCapacity);
}

- (uint8_t *)encBufferAligned
{
    return [[self class] alignedPointer:self.encBuffer];
}

- (uint8_t *)decBufferAligned
{
    return [[self class] alignedPointer:self.decBuffer];
}

- (void)setCompressionFraming:(CompressionFramingNative)compressionFraming
{
    __weak DataPath *weakSelf = self;

    DataPathParseBlock parseCompressedBlock = ^BOOL(uint8_t * _Nonnull payload, NSInteger * _Nonnull payloadOffset, uint8_t * _Nonnull compressionHeader, NSInteger * _Nonnull headerLength, const uint8_t * _Nonnull packet, NSInteger packetLength, NSError * _Nullable __autoreleasing * _Nullable error) {
        *compressionHeader = payload[0];
        *headerLength = 1;

        switch (*compressionHeader) {
            case DataPacketNoCompress:
                *payloadOffset = 1;
                break;
                
            case DataPacketNoCompressSwap:
                payload[0] = packet[packetLength - 1];
                *payloadOffset = 0;
                break;
                
            case DataPacketLZOCompress:
                if (!weakSelf.lzo) { // compressed packet unexpected
                    if (error) {
                        *error = TunnelKitErrorWithCode(TunnelKitErrorCodeDataPathCompression);
                    }
                    return NO;
                }
                *payloadOffset = 1;
                break;
                
            default:
                // @"Expected NO_COMPRESS (found %X != %X)", payload[0], DataPacketNoCompress);
                if (error) {
                    *error = TunnelKitErrorWithCode(TunnelKitErrorCodeDataPathCompression);
                }
                return NO;
        }
        return YES;
    };

    switch (compressionFraming) {
        case CompressionFramingNativeDisabled: {
            self.assemblePayloadBlock = ^(uint8_t * packetDest, NSInteger * packetLengthOffset, NSData * payload) {
                memcpy(packetDest, payload.bytes, payload.length);
                *packetLengthOffset = 0;
            };
            self.parsePayloadBlock = ^BOOL(uint8_t * _Nonnull payload, NSInteger * _Nonnull payloadOffset, uint8_t * _Nonnull compressionHeader, NSInteger * _Nonnull headerLength, const uint8_t * _Nonnull packet, NSInteger packetLength, NSError * _Nullable __autoreleasing * _Nullable error) {
                *payloadOffset = 0;
                *compressionHeader = 0x00;
                *headerLength = 0;
                return YES;
            };
            break;
        }
        case CompressionFramingNativeCompress: {
            self.assemblePayloadBlock = ^(uint8_t * packetDest, NSInteger * packetLengthOffset, NSData * payload) {
                NSData *compressedPayload = [weakSelf.lzo compressedDataWithData:payload error:NULL];
                if (compressedPayload) {
                    packetDest[0] = DataPacketLZOCompress;
                    *packetLengthOffset = 1 - (payload.length - compressedPayload.length);
                    payload = compressedPayload;
                    memcpy(packetDest + 1, payload.bytes, payload.length);
                } else {
                    *packetLengthOffset = 1;

                    // do not byte swap if compression enabled
                    if (weakSelf.lzo) {
                        packetDest[0] = DataPacketNoCompress;
                        memcpy(packetDest + 1, payload.bytes, payload.length);
                    } else {
                        memcpy(packetDest, payload.bytes, payload.length);
                        packetDest[payload.length] = packetDest[0];
                        packetDest[0] = DataPacketNoCompressSwap;
                    }
                }
            };
            self.parsePayloadBlock = parseCompressedBlock;
            break;
        }
        case CompressionFramingNativeCompLZO: {
            self.assemblePayloadBlock = ^(uint8_t * packetDest, NSInteger * packetLengthOffset, NSData * payload) {
                NSData *compressedPayload = [weakSelf.lzo compressedDataWithData:payload error:NULL];
                if (compressedPayload) {
                    packetDest[0] = DataPacketLZOCompress;
                    *packetLengthOffset = 1 - (payload.length - compressedPayload.length);
                    payload = compressedPayload;
                } else {
                    packetDest[0] = DataPacketNoCompress;
                    *packetLengthOffset = 1;
                }
                memcpy(packetDest + 1, payload.bytes, payload.length);
            };
            self.parsePayloadBlock = parseCompressedBlock;
            break;
        }
    }
}

#pragma mark DataPath

- (NSArray<NSData *> *)encryptPackets:(NSArray<NSData *> *)packets key:(uint8_t)key error:(NSError *__autoreleasing *)error
{
//    NSAssert(self.encrypter.peerId == self.decrypter.peerId, @"Peer-id mismatch in DataPath encrypter/decrypter");
    
    if (self.outPacketId > self.maxPacketId) {
        if (error) {
            *error = TunnelKitErrorWithCode(TunnelKitErrorCodeDataPathOverflow);
        }
        return nil;
    }
    
    [self.outPackets removeAllObjects];
    
    for (NSData *payload in packets) {
        self.outPacketId += 1;
        
        // may resize encBuffer to hold encrypted payload
        [self adjustEncBufferToPacketSize:(int)payload.length];
        
        uint8_t *dataPacketBytes = self.encBufferAligned;
        NSInteger dataPacketLength;
        [self.encrypter assembleDataPacketWithBlock:self.assemblePayloadBlock
                                           packetId:self.outPacketId
                                            payload:payload
                                               into:dataPacketBytes
                                             length:&dataPacketLength];
        MSSFix(dataPacketBytes, dataPacketLength);
        
        NSData *encryptedDataPacket = [self.encrypter encryptedDataPacketWithKey:key
                                                                        packetId:self.outPacketId
                                                                     packetBytes:dataPacketBytes
                                                                    packetLength:dataPacketLength
                                                                           error:error];
        if (!encryptedDataPacket) {
            return nil;
        }
        
        [self.outPackets addObject:encryptedDataPacket];
    }
    
    return self.outPackets;
}

- (NSArray<NSData *> *)decryptPackets:(NSArray<NSData *> *)packets keepAlive:(bool *)keepAlive error:(NSError *__autoreleasing *)error
{
//    NSAssert(self.encrypter.peerId == self.decrypter.peerId, @"Peer-id mismatch in DataPath encrypter/decrypter");

    [self.inPackets removeAllObjects];
    
    for (NSData *encryptedDataPacket in packets) {
        
        // may resize decBuffer to encryptedPacket.length
        [self adjustDecBufferToPacketSize:(int)encryptedDataPacket.length];
        
        uint8_t *dataPacketBytes = self.decBufferAligned;
        NSInteger dataPacketLength = INT_MAX;
        uint32_t packetId;
        const BOOL success = [self.decrypter decryptDataPacket:encryptedDataPacket
                                                          into:dataPacketBytes
                                                        length:&dataPacketLength
                                                      packetId:&packetId
                                                         error:error];
        if (!success) {
            return nil;
        }
        if (packetId > self.maxPacketId) {
            if (error) {
                *error = TunnelKitErrorWithCode(TunnelKitErrorCodeDataPathOverflow);
            }
            return nil;
        }
        if (self.inReplay && [self.inReplay isReplayedPacketId:packetId]) {
            continue;
        }
        
        uint8_t compressionHeader;
        NSData *payload = [self.decrypter parsePayloadWithBlock:self.parsePayloadBlock
                                              compressionHeader:&compressionHeader
                                                    packetBytes:dataPacketBytes
                                                   packetLength:dataPacketLength
                                                          error:error];
        if (!payload) {
            return nil;
        }
        if (compressionHeader == DataPacketLZOCompress) {
            payload = [self.lzo decompressedDataWithData:payload error:error];
            if (!payload) {
                return nil;
            }
        }

        if ((payload.length == sizeof(DataPacketPingData)) && !memcmp(payload.bytes, DataPacketPingData, payload.length)) {
            if (keepAlive) {
                *keepAlive = true;
            }
            continue;
        }
        
//        MSSFix(payloadBytes, payloadLength);
        
        [self.inPackets addObject:payload];
    }
    
    return self.inPackets;
}

@end
