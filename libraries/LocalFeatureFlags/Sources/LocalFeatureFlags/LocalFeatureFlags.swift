import Foundation
import os.log

/// A `FeatureFlag` has a category that the feature falls into, as well as a short string key describing that feature.
public protocol FeatureFlag {
    var category: String { get }
    var feature: String { get }
}

/// Handy for enums.
public extension FeatureFlag where Self: RawRepresentable, RawValue == String {
    var feature: String { rawValue }
}

/// For QA and reverting purposes, `setOverrides` lets the client application override local feature flags from the API.
public func setLocalFeatureFlagOverrides(_ dict: [String: Any]?) {
    Sync.async {
        overrides = dict
    }
}

/// Check if a given flag is enabled. First checks the overrides, then the local built-in flags, then returns false.
/// - Note: `FeatureFlags` is generated from `FeatureFlags.plist` using the `plutil` tool.
public func isEnabled(_ flag: FeatureFlag) -> Bool {
    isOverridden(category: flag.category, feature: flag.feature) ??
        isEnabled(dict: featureFlags, category: flag.category, feature: flag.feature) ??
        false
}

// MARK: - Private properties and methods

private var overrides: [String: Any]?

private func isOverridden(category: String, feature: String) -> Bool? {
    Sync.sync {
        isEnabled(dict: overrides, category: category, feature: feature)
    }
}

private func isEnabled(dict: [String: Any]?, category: String, feature: String) -> Bool? {
    guard let category = dict?[category] as? [String: Any] else {
        return nil
    }

    return category[feature] as? Bool
}

/// Closures are modified for testing purposes.
internal enum Sync {
    /// Concurrent queue for thread-safe updates to the overrides dictionary.
    private static let queue = DispatchQueue(label: "ch.protonvpn.feature_flags.sync", attributes: .concurrent)

    /// Perform an asynchronous write with a barrier.
    static var `async`: (@escaping () -> Void) -> () = {
        queue.async(flags: .barrier, execute: $0)
    }

    /// Perform a synchronous read. (Note that the queue is concurrent.)
    static var `sync`: (@escaping () -> Bool?) -> Bool? = {
        queue.sync(execute: $0)
    }
}
