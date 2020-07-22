//
//  LZO.h
//  TunnelKit
//
//  Created by Davide De Rosa on 3/18/19.
//  Copyright (c) 2020 Davide De Rosa. All rights reserved.
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

@protocol LZO

- (nullable NSData *)compressedDataWithData:(NSData *)data error:(NSError **)error;
- (nullable NSData *)decompressedDataWithData:(NSData *)data error:(NSError **)error;
- (nullable NSData *)decompressedDataWithBytes:(const uint8_t *)bytes length:(NSInteger)length error:(NSError **)error;

@end

//+ (NSString *)versionString;
BOOL LZOIsSupported(void);
id<LZO> LZOCreate(void);

NS_ASSUME_NONNULL_END
