import Foundation

public protocol KeyPairProtocol {
    associatedtype PublicKey where PublicKey == Bytes
    associatedtype SecretKey where SecretKey == Bytes
    var publicKey: PublicKey { get }
    var secretKey: SecretKey { get }

    init (publicKey: PublicKey, secretKey: SecretKey)
}
