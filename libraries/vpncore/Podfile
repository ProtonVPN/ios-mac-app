source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

workspace 'vpncore'

# ignore all warnings from all pods
inhibit_all_warnings!

abstract_target 'vpncore' do
    # third party pods
    pod 'Alamofire', '~> 5.2'
    pod 'KeychainAccess', '~> 3.0'
    pod 'Sentry', '~> 4.0'
    pod 'ReachabilitySwift', '~> 4.0'
    
    # OpenVPN support
    pod 'TunnelKit', :path => '../tunnelkit', :branch => 'keychain_avoid'

    # Checks code style and bad practices
    pod 'SwiftLint'

    # Certificates pinning
    pod 'TrustKit'
    
    target 'vpncore-ios' do
        platform :ios, '11.0'
    end
    target 'vpncore-macos' do
        platform :osx, '10.12'
    end
    target 'vpncore-iosTests' do
        platform :ios, '11.0'
    end
    target 'vpncore-macosTests' do
        platform :osx, '10.12'
    end
end

post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-vpncore-vpncore-ios/Pods-vpncore-vpncore-ios-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')
end