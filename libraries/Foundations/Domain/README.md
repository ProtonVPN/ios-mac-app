# Domain

Foundational models from the VPN domain depended on by most features in the project.

As more models are migrated here from `VPNShared`, `VPNAppCore` and `LegacyCommon`, Domain could be split into smaller, more specific targets.

These are the business layer models, and should be implemented separately from their respective Data Transfer Object (DTO) and Database Entity/Record definitions.

Business logic that operates on these types should be implemented in extensions in higher level packages.
