//
//  CryptoBox.m
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

#import <openssl/evp.h>
#import <openssl/hmac.h>
#import <openssl/rand.h>

#import "CryptoBox.h"
#import "CryptoMacros.h"
#import "Allocation.h"
#import "Errors.h"

#import "CryptoCBC.h"
#import "CryptoAEAD.h"
#import "CryptoCTR.h"

@interface CryptoBox ()

@property (nonatomic, strong) NSString *cipherAlgorithm;
@property (nonatomic, strong) NSString *digestAlgorithm;
@property (nonatomic, assign) NSInteger digestLength;
@property (nonatomic, assign) NSInteger tagLength;

@property (nonatomic, strong) id<Encrypter> encrypter;
@property (nonatomic, strong) id<Decrypter> decrypter;

@end

@implementation CryptoBox

+ (void)initialize
{
}

+ (NSString *)version
{
    return [NSString stringWithCString:OpenSSL_version(OPENSSL_VERSION) encoding:NSASCIIStringEncoding];
}

+ (BOOL)preparePRNGWithSeed:(const uint8_t *)seed length:(NSInteger)length
{
    unsigned char x[1];
    // make sure its initialized before seeding
    if (RAND_bytes(x, 1) != 1) {
        return NO;
    }
    RAND_seed(seed, (int)length);
    return YES;
}

- (instancetype)initWithCipherAlgorithm:(NSString *)cipherAlgorithm digestAlgorithm:(NSString *)digestAlgorithm
{
    NSParameterAssert(cipherAlgorithm || digestAlgorithm);
    
    if ((self = [super init])) {
        self.cipherAlgorithm = [cipherAlgorithm lowercaseString];
        self.digestAlgorithm = [digestAlgorithm lowercaseString];
    }
    return self;
}

- (void)dealloc
{
    self.encrypter = nil;
    self.decrypter = nil;
}

// these keys are coming from the OpenVPN negotiation despite the cipher
- (BOOL)configureWithCipherEncKey:(ZeroingData *)cipherEncKey
                     cipherDecKey:(ZeroingData *)cipherDecKey
                       hmacEncKey:(ZeroingData *)hmacEncKey
                       hmacDecKey:(ZeroingData *)hmacDecKey
                            error:(NSError *__autoreleasing *)error
{
    NSParameterAssert((cipherEncKey && cipherDecKey) || (hmacEncKey && hmacDecKey));

    if (self.cipherAlgorithm) {
        if ([self.cipherAlgorithm hasSuffix:@"-cbc"]) {
            if (!self.digestAlgorithm) {
                if (error) {
                    *error = TunnelKitErrorWithCode(TunnelKitErrorCodeCryptoAlgorithm);
                }
                return NO;
            }
            CryptoCBC *cbc = [[CryptoCBC alloc] initWithCipherName:self.cipherAlgorithm digestName:self.digestAlgorithm];
            self.encrypter = cbc;
            self.decrypter = cbc;
        }
        else if ([self.cipherAlgorithm hasSuffix:@"-gcm"]) {
            CryptoAEAD *gcm = [[CryptoAEAD alloc] initWithCipherName:self.cipherAlgorithm];
            self.encrypter = gcm;
            self.decrypter = gcm;
        }
        else if ([self.cipherAlgorithm hasSuffix:@"-ctr"]) {
            CryptoCTR *ctr = [[CryptoCTR alloc] initWithCipherName:self.cipherAlgorithm digestName:self.digestAlgorithm];
            self.encrypter = ctr;
            self.decrypter = ctr;
        }
        // not supported
        else {
            if (error) {
                *error = TunnelKitErrorWithCode(TunnelKitErrorCodeCryptoAlgorithm);
            }
            return NO;
        }
    }
    else {
        CryptoCBC *cbc = [[CryptoCBC alloc] initWithCipherName:nil digestName:self.digestAlgorithm];
        self.encrypter = cbc;
        self.decrypter = cbc;
    }
    
    [self.encrypter configureEncryptionWithCipherKey:cipherEncKey hmacKey:hmacEncKey];
    [self.decrypter configureDecryptionWithCipherKey:cipherDecKey hmacKey:hmacDecKey];

    NSAssert(self.encrypter.digestLength == self.decrypter.digestLength, @"Digest length mismatch in encrypter/decrypter");
    self.digestLength = self.encrypter.digestLength;
    self.tagLength = self.encrypter.tagLength;

    return YES;
}

+ (BOOL)hmacWithDigestName:(NSString *)digestName
                    secret:(const uint8_t *)secret
              secretLength:(NSInteger)secretLength
                      data:(const uint8_t *)data
                dataLength:(NSInteger)dataLength
                      hmac:(uint8_t *)hmac
                hmacLength:(NSInteger *)hmacLength
                     error:(NSError **)error
{
    NSParameterAssert(digestName);
    NSParameterAssert(secret);
    NSParameterAssert(data);
    
    unsigned int l = 0;
    int code = 1;

    HMAC_CTX *ctx = HMAC_CTX_new();
    TUNNEL_CRYPTO_TRACK_STATUS(code) HMAC_CTX_reset(ctx);
    TUNNEL_CRYPTO_TRACK_STATUS(code) HMAC_Init_ex(ctx, secret, (int)secretLength, EVP_get_digestbyname([digestName cStringUsingEncoding:NSASCIIStringEncoding]), NULL);
    TUNNEL_CRYPTO_TRACK_STATUS(code) HMAC_Update(ctx, data, dataLength);
    TUNNEL_CRYPTO_TRACK_STATUS(code) HMAC_Final(ctx, hmac, &l);
    HMAC_CTX_free(ctx);
    
    *hmacLength = l;

    TUNNEL_CRYPTO_RETURN_STATUS(code)
}

@end
