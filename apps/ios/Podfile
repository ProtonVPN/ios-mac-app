source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '11.0'

use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

def sharedpods
  # development pods
  pod 'vpncore', :path => '../vpncore' # run `pod update vpncore` after changing source

  # third party pods
  pod 'Alamofire', '~> 4.0'
  pod 'GSMessages', '~> 1.0'
  pod 'KeychainAccess', '~> 3.0'
  pod 'ReachabilitySwift', '~> 4.0'
  pod 'Sentry', '~> 4.0'

  # Checks code style and bad practices
  pod 'SwiftLint'

end

target 'ProtonVPN' do
  sharedpods
  
  target 'OpenVPN Extension' do
    inherit! :search_paths
  end    

  target 'Quick Connect Widget' do
    inherit! :search_paths
  end
    
  target 'Siri Shortuct Handler' do
    inherit! :search_paths
  end
    
  target 'ProtonVPNTests' do
    inherit! :search_paths
  end
end

plugin 'cocoapods-acknowledgements', :settings_bundle => true, :exclude => ['vpncore']

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
