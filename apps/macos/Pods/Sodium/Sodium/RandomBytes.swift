import Foundation
import Clibsodium

public struct RandomBytes {
    public let SeedBytes = Int(randombytes_seedbytes())
}

extension RandomBytes {
    /**
     Returns a `Bytes object of length `length` containing an unpredictable sequence of bytes.

     - Parameter length: The number of bytes to generate.

     - Returns: The generated data.
     */
    public func buf(length: Int) -> Bytes? {
        guard length >= 0 else { return nil }
        var output = Bytes(count: length)
        randombytes_buf(&output, length)
        return output
    }

    /**
     - Returns: An unpredictable value between 0 and 0xffffffff (included).
     */
    public func random() -> UInt32 {
        return randombytes_random()
    }

    /**
     Returns an unpredictable value between 0 and `upper_bound` (excluded). Unlike randombytes_random() % upper_bound, it does its best to guarantee a uniform distribution of the possible output values even when upper_bound is not a power of 2.

     - Parameter upperBound: The upper bound (excluded) of the returned value.

     - Returns: The unpredictable value.
     */
    public func uniform(upperBound: UInt32) -> UInt32 {
        return randombytes_uniform(upperBound)
    }

    /**
     Returns a deterministic stream of unbiased bits derived from a seed.

     - Parameter length: The number of bytes to generate.
     - Parameter seed: The seed.

     - Returns: The generated data.
     */
    public func deterministic(length: Int, seed: Bytes) -> Bytes? {
        guard length >= 0,
              seed.count == SeedBytes,
              Int64(length) <= 0x4000000000 as Int64
        else { return nil }

        var output = Bytes(count: length)
        randombytes_buf_deterministic(&output, length, seed)
        return output
    }
}
