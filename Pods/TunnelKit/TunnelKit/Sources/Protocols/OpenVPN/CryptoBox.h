//
//  CryptoBox.h
//  TunnelKit
//
//  Created by Davide De Rosa on 2/4/17.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ZeroingData;
@protocol Encrypter;
@protocol Decrypter;

@interface CryptoBox : NSObject

+ (NSString *)version;
+ (BOOL)preparePRNGWithSeed:(const uint8_t *)seed length:(NSInteger)length;

- (instancetype)initWithCipherAlgorithm:(nullable NSString *)cipherAlgorithm
                                digestAlgorithm:(nullable NSString *)digestAlgorithm;

- (BOOL)configureWithCipherEncKey:(nullable ZeroingData *)cipherEncKey
                     cipherDecKey:(nullable ZeroingData *)cipherDecKey
                       hmacEncKey:(nullable ZeroingData *)hmacEncKey
                       hmacDecKey:(nullable ZeroingData *)hmacDecKey
                            error:(NSError **)error;

// WARNING: hmac must be able to hold HMAC result
+ (BOOL)hmacWithDigestName:(NSString *)digestName
                    secret:(const uint8_t *)secret
              secretLength:(NSInteger)secretLength
                      data:(const uint8_t *)data
                dataLength:(NSInteger)dataLength
                      hmac:(uint8_t *)hmac
                hmacLength:(NSInteger *)hmacLength
                     error:(NSError **)error;


// encrypt/decrypt are mutually thread-safe
- (id<Encrypter>)encrypter;
- (id<Decrypter>)decrypter;

- (NSInteger)digestLength;
- (NSInteger)tagLength;

@end

NS_ASSUME_NONNULL_END
