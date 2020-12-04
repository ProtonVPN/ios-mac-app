source 'https://github.com/CocoaPods/Specs.git'

platform :osx, '10.12'

use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

def tunnelkit_pod
  pod 'TunnelKit', :path => '../tunnelkit', :branch => 'keychain_avoid'
end

def common_pods
    # development pods
    tunnelkit_pod
    pod 'vpncore', :path => '../vpncore' # run `pod update vpncore` after changing source
end

target 'ProtonVPN' do
    common_pods
    # third party pods
    pod 'Alamofire', '~> 5.1'
    pod 'KeychainAccess', '~> 3.0'
    pod 'ReachabilitySwift', '~> 4.0'
    pod 'Sentry', '~> 4.0'
    pod 'Sparkle', '~> 1.0'
    pod 'SDWebImage', '~> 5.0'
    
    # Checks code style and bad practices
    pod 'SwiftLint'
end

target 'ProtonVPN OpenVPN' do
  tunnelkit_pod
end

target 'ProtonVPNTests' do
    inherit! :search_paths
    common_pods
end

post_install do | installer |
    # Create plist with info about used frameworks
    plugin 'cocoapods-acknowledgements', :exclude => ['vpncore']

    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-ProtonVPN/Pods-ProtonVPN-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')
    
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        # Reset deployment targets to use the one we have on the main project
        config.build_settings.delete 'MACOSX_DEPLOYMENT_TARGET'
        
        # Exclude arm64 architecture until we support it
        config.build_settings["EXCLUDED_ARCHS"] = "arm64"
      end
    end
end
