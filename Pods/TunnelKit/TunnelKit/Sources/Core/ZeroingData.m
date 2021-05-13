//
//  ZeroingData.m
//  TunnelKit
//
//  Created by Davide De Rosa on 4/28/17.
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

#import "ZeroingData.h"
#import "Allocation.h"

@interface ZeroingData () {
    uint8_t *_bytes;
}

@end

@implementation ZeroingData

- (instancetype)init
{
    return [self initWithBytes:NULL count:0];
}

- (instancetype)initWithCount:(NSInteger)count
{
    if ((self = [super init])) {
        _count = count;
        _bytes = allocate_safely(count);
    }
    return self;
}

- (instancetype)initWithBytes:(const uint8_t *)bytes count:(NSInteger)count
{
//    NSParameterAssert(bytes);

    if ((self = [super init])) {
        _count = count;
        _bytes = allocate_safely(count);
        memcpy(_bytes, bytes, count);
    }
    return self;
}

- (instancetype)initWithBytesNoCopy:(uint8_t *)bytes count:(NSInteger)count
{
    NSParameterAssert(bytes);

    if ((self = [super init])) {
        _count = count;
        _bytes = bytes;
    }
    return self;
}

- (instancetype)initWithUInt8:(uint8_t)uint8
{
    if ((self = [super init])) {
        _count = 1;
        _bytes = allocate_safely(_count);
        _bytes[0] = uint8;
    }
    return self;
}

- (instancetype)initWithUInt16:(uint16_t)uint16
{
    if ((self = [super init])) {
        _count = 2;
        _bytes = allocate_safely(_count);
        _bytes[0] = (uint16 & 0xff);
        _bytes[1] = (uint16 >> 8);
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data
{
    return [self initWithData:data offset:0 count:data.length];
}

- (instancetype)initWithData:(NSData *)data offset:(NSInteger)offset count:(NSInteger)count
{
    NSParameterAssert(data);
//    NSParameterAssert(offset <= data.length);
    NSParameterAssert(offset + count <= data.length);

    if ((self = [super init])) {
        _count = count;
        _bytes = allocate_safely(count);
        memcpy(_bytes, data.bytes + offset, count);
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string nullTerminated:(BOOL)nullTerminated
{
    NSParameterAssert(string);

    if ((self = [super init])) {
        const char *stringBytes = [string cStringUsingEncoding:NSASCIIStringEncoding];
        const int stringLength = (int)string.length;
        
        _count = stringLength + (nullTerminated ? 1 : 0);
        _bytes = allocate_safely(_count);
        memcpy(_bytes, stringBytes, stringLength);
        if (nullTerminated) {
            _bytes[stringLength] = '\0';
        }
    }
    return self;
}

- (void)dealloc
{
    bzero(_bytes, _count);
    free(_bytes);
}

- (const uint8_t *)bytes
{
    return _bytes;
}

- (uint8_t *)mutableBytes
{
    return _bytes;
}

- (void)appendData:(ZeroingData *)other
{
    NSParameterAssert(other);

    const NSInteger newCount = _count + other.count;
    uint8_t *newBytes = allocate_safely(newCount);
    memcpy(newBytes, _bytes, _count);
    memcpy(newBytes + _count, other.bytes, other.count);
    
    bzero(_bytes, _count);
    free(_bytes);
    
    _bytes = newBytes;
    _count = newCount;
}

- (void)truncateToSize:(NSInteger)size
{
    NSParameterAssert(size <= _count);
    
    uint8_t *newBytes = allocate_safely(size);
    memcpy(newBytes, _bytes, size);

    bzero(_bytes, _count);
    free(_bytes);
    
    _bytes = newBytes;
    _count = size;
}

- (void)removeUntilOffset:(NSInteger)until
{
    NSParameterAssert(until <= _count);
    
    const NSInteger newCount = _count - until;
    uint8_t *newBytes = allocate_safely(newCount);
    memcpy(newBytes, _bytes + until, newCount);
    
    bzero(_bytes, _count);
    free(_bytes);
    
    _bytes = newBytes;
    _count = newCount;
}

- (void)zero
{
    bzero(_bytes, _count);
}

- (ZeroingData *)appendingData:(ZeroingData *)other
{
    NSParameterAssert(other);

    const NSInteger newCount = _count + other.count;
    uint8_t *newBytes = allocate_safely(newCount);
    memcpy(newBytes, _bytes, _count);
    memcpy(newBytes + _count, other.bytes, other.count);
    
    return [[ZeroingData alloc] initWithBytesNoCopy:newBytes count:newCount];
}

- (ZeroingData *)withOffset:(NSInteger)offset count:(NSInteger)count
{
//    NSParameterAssert(offset <= _count);
    NSParameterAssert(offset + count <= _count);

    uint8_t *newBytes = allocate_safely(count);
    memcpy(newBytes, _bytes + offset, count);
    
    return [[ZeroingData alloc] initWithBytesNoCopy:newBytes count:count];
}

- (uint16_t)UInt16ValueFromOffset:(NSInteger)from
{
    NSParameterAssert(from + 2 <= _count);

    uint16_t value = 0;
    value |= _bytes[from];
    value |= _bytes[from + 1] << 8;
    return value;
}

- (uint16_t)networkUInt16ValueFromOffset:(NSInteger)from
{
    NSParameterAssert(from + 2 <= _count);
    
    uint16_t value = 0;
    value |= _bytes[from];
    value |= _bytes[from + 1] << 8;
    return CFSwapInt16BigToHost(value);
}

- (NSString *)nullTerminatedStringFromOffset:(NSInteger)from
{
    NSParameterAssert(from <= _count);

    NSInteger nullOffset = NSNotFound;
    for (NSInteger i = from; i < _count; ++i) {
        if (_bytes[i] == 0) {
            nullOffset = i;
            break;
        }
    }
    if (nullOffset == NSNotFound) {
        return nil;
    }
    const NSInteger stringLength = nullOffset - from;
    return [[NSString alloc] initWithBytes:_bytes length:stringLength encoding:NSASCIIStringEncoding];
}

- (BOOL)isEqualToData:(NSData *)data
{
    NSParameterAssert(data);

    if (data.length != _count) {
        return NO;
    }
    return !memcmp(_bytes, data.bytes, _count);
}

- (NSData *)toData
{
    return [NSData dataWithBytes:_bytes length:_count];
}

- (NSString *)toHex
{
    const NSUInteger capacity = _count * 2;
    NSMutableString *hexString = [[NSMutableString alloc] initWithCapacity:capacity];
    for (int i = 0; i < _count; ++i) {
        [hexString appendFormat:@"%02x", _bytes[i]];
    }
    return hexString;
}

@end
