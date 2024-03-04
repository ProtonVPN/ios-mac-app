import Foundation
import System
import PMLogger

/// A `FeatureFlag` has a category that the feature falls into, as well as a short string key describing that feature.
public protocol FeatureFlag {
    var category: String { get }
    var feature: String { get }
}

private enum FeatureFlagsData {
    private class BundleFinder {}

    static let featureFlagsURL: URL? = {
        let findPlist = { (bundle: Bundle) -> URL? in
            bundle.url(forResource: "LocalFeatureFlags", withExtension: "plist")
        }

        #if DEBUG
        let candidates = Set([Bundle.main, Bundle(for: BundleFinder.self)])
            .union(Bundle.allBundles)
            .union(Bundle.allFrameworks)
            .union( // Env vars set by Xcode or Swift build system
                ["PACKAGE_RESOURCE_BUNDLE_URL", "XCTestBundlePath"]
                    .compactMap { key -> Bundle? in
                        guard let path = ProcessInfo.processInfo.environment[key] else { return nil }
                        guard let bundle = Bundle(path: path) else { return nil }
                        return bundle
                    }
            )

        // First look in the bundles themselves
        if let url = candidates.compactMap(findPlist).first {
            return url
        }

        if let url = candidates.flatMap({ (bundle: Bundle) -> [URL] in
            guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: bundle.bundleURL,
                    includingPropertiesForKeys: nil
                  ) else {
                return []
            }
            return contents.compactMap {
                if let bundle = Bundle(url: $0),
                   let url = findPlist(bundle) {
                    return url
                }
                return nil
            }
        }).first {
            return url
        }

        // If they aren't in the bundles, check every bundle in each bundle's Resources/ directory.
        if let url = candidates.flatMap({ (bundle: Bundle) -> [URL] in
            guard let resourceUrl = bundle.resourceURL,
                  let contents = try? FileManager.default.contentsOfDirectory(
                    at: resourceUrl,
                    includingPropertiesForKeys: nil
                  ) else {
                return []
            }
            return contents.compactMap {
                if let bundle = Bundle(url: $0),
                   let url = findPlist(bundle) {
                    return url
                }
                return nil
            }
        }).first {
            return url
        }

        return findPlist(Bundle.module)
        #else
        return findPlist(Bundle.module)
        #endif
    }()

    static let featureFlags: [String: Any] = {
        guard let featureFlagsURL else {
            log.assertionFailure("Couldn't find feature flags plist")
            return [:]
        }

        guard let data = try? Data(contentsOf: featureFlagsURL) else {
            fatalError("Couldn't read feature flag resource at \(featureFlagsURL.absoluteString)")
        }

        guard let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            fatalError("Feature flags have unknown format")
        }

        return dict
    }()
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
        isEnabled(dict: FeatureFlagsData.featureFlags, category: flag.category, feature: flag.feature) ??
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
