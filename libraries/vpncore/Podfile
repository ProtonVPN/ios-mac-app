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

    # Core
    pod 'PMNetworking', :path => '../pmnetworking' # run `pod update PMNetworking` after changing source
    
    # OpenVPN support
    pod 'TunnelKit', :git => 'https://github.com/passepartoutvpn/tunnelkit', :commit => 'fe697c2c564b5a5339545a1fc5aa737bf3124b24'

    # Checks code style and bad practices
    pod 'SwiftLint'

    # Certificates pinning
    pod 'TrustKit', :git => 'https://github.com/ProtonMail/TrustKit', :commit => '838fba789e01c9cabff77acea3fb7135f71a220f'
    
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
