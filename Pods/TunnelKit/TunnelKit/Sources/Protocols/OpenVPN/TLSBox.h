//
//  TLSBox.h
//  TunnelKit
//
//  Created by Davide De Rosa on 2/3/17.
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

extern const NSInteger TLSBoxMaxBufferLength;

extern NSString *const TLSBoxPeerVerificationErrorNotification;

extern const NSInteger TLSBoxDefaultSecurityLevel;

//
// cipher text is safe within NSData
// plain text might be sensitive and must avoid NSData
//
// WARNING: not thread-safe!
//
@interface TLSBox : NSObject

@property (nonatomic, assign) NSInteger securityLevel; // TLSBoxDefaultSecurityLevel for default

+ (nullable NSString *)md5ForCertificatePath:(NSString *)path error:(NSError **)error;
+ (nullable NSString *)decryptedPrivateKeyFromPath:(NSString *)path passphrase:(NSString *)passphrase error:(NSError **)error;
+ (nullable NSString *)decryptedPrivateKeyFromPEM:(NSString *)pem passphrase:(NSString *)passphrase error:(NSError **)error;

- (instancetype)initWithCAPath:(NSString *)caPath
         clientCertificatePath:(nullable NSString *)clientCertificatePath
                 clientKeyPath:(nullable NSString *)clientKeyPath
                     checksEKU:(BOOL)checksEKU
                 checksSANHost:(BOOL)checksSANHost
                      hostname:(nullable NSString *)hostname;

- (BOOL)startWithError:(NSError **)error;

- (nullable NSData *)pullCipherTextWithError:(NSError **)error;
// WARNING: text must be able to hold plain text output
- (BOOL)pullRawPlainText:(uint8_t *)text length:(NSInteger *)length error:(NSError **)error;

- (BOOL)putCipherText:(NSData *)text error:(NSError **)error;
- (BOOL)putRawCipherText:(const uint8_t *)text length:(NSInteger)length error:(NSError **)error;
- (BOOL)putPlainText:(NSString *)text error:(NSError **)error;
- (BOOL)putRawPlainText:(const uint8_t *)text length:(NSInteger)length error:(NSError **)error;

- (BOOL)isConnected;

@end

NS_ASSUME_NONNULL_END
