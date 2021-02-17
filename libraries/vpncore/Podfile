source 'https://github.com/CocoaPods/Specs.git'
use_frameworks!

workspace 'vpncore'

# ignore all warnings from all pods
inhibit_all_warnings!

abstract_target 'vpncore' do
    # third party pods
    pod 'Alamofire', '5.3.0'
    pod 'KeychainAccess', '3.2.1'
    pod 'Sentry', '4.5.0'
    pod 'ReachabilitySwift', '5.0.0'
    
    # OpenVPN support
    pod 'TunnelKit', :path => '../tunnelkit'

    # Checks code style and bad practices
    pod 'SwiftLint'

    # Certificates pinning
    pod 'TrustKit', '1.6.5'
    
    target 'vpncore-ios' do
        platform :ios, '12.0'
    end
    target 'vpncore-macos' do
        platform :osx, '10.15'
    end
    target 'vpncore-iosTests' do
        platform :ios, '12.0'
    end
    target 'vpncore-macosTests' do
        platform :osx, '10.15'
    end
end

post_install do | installer |
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-vpncore-vpncore-ios/Pods-vpncore-vpncore-ios-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')
end
