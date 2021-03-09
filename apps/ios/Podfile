source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '11.0'

use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

def sharedpods
  # development pods
  pod 'TunnelKit', :git => 'https://github.com/passepartoutvpn/tunnelkit', :commit => 'fe697c2c564b5a5339545a1fc5aa737bf3124b24'
  pod 'vpncore', :path => '../vpncore' # run `pod update vpncore` after changing source

  # Core
  pod 'PMNetworking', :path => '../pmnetworking' # run `pod update PMNetworking` after changing source
  pod 'PMChallenge', :path => '../pmchallenge' # run `pod update PMChallenge` after changing source

  # third party pods
  pod 'GSMessages', '~> 1.0'
  pod 'KeychainAccess', '3.2.1'
  pod 'ReachabilitySwift', '5.0.0'
  pod 'Sentry', '4.5.0'
  pod 'AlamofireImage', '~> 4.1'

  # Checks code style and bad practices
  pod 'SwiftLint'

  # OpenVPN support
  pod 'TunnelKit', :git => 'https://github.com/passepartoutvpn/tunnelkit', :commit => 'fe697c2c564b5a5339545a1fc5aa737bf3124b24'

  # Certificates pinning
  pod 'TrustKit', :git => 'https://github.com/ProtonMail/TrustKit', :commit => '838fba789e01c9cabff77acea3fb7135f71a220f'
  
end

target 'ProtonVPN' do
  sharedpods
  
  target 'OpenVPN Extension' do
    inherit! :search_paths
  end    

  target 'Quick Connect Widget' do
    inherit! :search_paths
  end
    
  target 'Siri Shortcut Handler' do
    inherit! :search_paths
  end
    
  target 'ProtonVPNTests' do
    inherit! :search_paths
  end
end

# Temporarily disabled while we have problems with CD
#plugin 'cocoapods-acknowledgements', :settings_bundle => true, :exclude => ['vpncore']

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end

  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-ProtonVPN/Pods-ProtonVPN-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')
end
