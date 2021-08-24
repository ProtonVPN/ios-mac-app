workspace 'ProtonVPN'

# ignore all warnings from all pods
inhibit_all_warnings!

def proton_url
  'git@' + ENV["PROTON_GIT_URL"]
end

def proton_core_path
    proton_url + ':apple/shared/protoncore.git'
end

def proton_core_version
  '2.4.0'
end

def openvpn
  pod 'TunnelKit', :git => proton_url + ':apple/vpn/tunnelkit.git', :branch => 'develop'
end

def pm_automation
  pod 'pmtest', :git => proton_url + ':apple/shared/pmtestautomation.git', :commit => '579ef5f66deea4231784614d936956982f53ee30'
end

def keychain_access
  pod 'KeychainAccess', '3.2.1'
end

def vpn_core
    use_frameworks!    
    pod 'Alamofire', '5.3.0'
    pod 'Sentry', '5.2.2'
    pod 'ReachabilitySwift', '5.0.0'
    keychain_access
    
    # Checks code style and bad practices
    pod 'SwiftLint'

    pod 'SwiftGen', '~> 6.0'

    # Certificates pinning
    pod 'TrustKit', :git => 'https://github.com/ProtonMail/TrustKit', :commit => '838fba789e01c9cabff77acea3fb7135f71a220f'
    
    openvpn

    # Core
    pod 'ProtonCore-Log', :git => proton_core_path, :tag => proton_core_version
    pod 'ProtonCore-Doh', :git => proton_core_path, :tag => proton_core_version
end    

abstract_target 'Core' do
    project 'libraries/vpncore/Core.xcodeproj'
    vpn_core

    target 'vpncore-ios' do       
        platform :ios, '12.1'
    end
    target 'vpncore-macos' do        
        platform :osx, '10.15'
    end
    target 'vpncore-iosTests' do
        platform :ios, '12.1'
    end
    target 'vpncore-macosTests' do
        platform :osx, '10.15'
    end
end

# iOS

target 'ProtonVPN' do
  project 'apps/iOS/iOS.xcodeproj'
  platform :ios, '12.1'
  use_frameworks!

  vpn_core

  pod 'GSMessages', '~> 1.0'
  pod 'AlamofireImage', '~> 4.1'
  
  pod 'ReachabilitySwift', '5.0.0'
  
  pod 'ProtonCore-Challenge', :git => proton_core_path, :tag => proton_core_version
  pod 'ProtonCore-Foundations', :git => proton_core_path, :tag => proton_core_version
  
  target 'OpenVPN Extension' do
    openvpn
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
  
  target 'ProtonVPNUITests' do
    platform :ios, '11.0'  
    pm_automation
  end

end

target 'WireGuardiOS Extension' do
  project 'apps/iOS/iOS.xcodeproj'
  platform :ios, '12.1'
  use_frameworks!
  
  keychain_access
end


# macOS

target 'ProtonVPN-mac' do
  project 'apps/macOS/macOS.xcodeproj'

  vpn_core

  # Third party pods
  pod 'SDWebImage', '5.10.0'

end

target 'ProtonVPN OpenVPN' do
  project 'apps/macOS/macOS.xcodeproj'
  vpn_core
end

target 'ProtonVPN WireGuard' do
  project 'apps/macOS/macOS.xcodeproj'
  use_frameworks!
  keychain_access
end

target 'ProtonVPNmacOSTests' do
  project 'apps/macOS/macOS.xcodeproj'
  inherit! :search_paths
  vpn_core
end

# Other

post_install do |installer|

  # Create plist with info about used frameworks
  plugin 'cocoapods-acknowledgements'
  require 'fileutils'
  FileUtils.cp_r('Pods/Target Support Files/Pods-ProtonVPN/Pods-ProtonVPN-acknowledgements.markdown', 'ACKNOWLEDGEMENTS.md')


  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.1'
      
      # Reset deployment targets to use the one we have on the main project
      config.build_settings.delete 'MACOSX_DEPLOYMENT_TARGET'
      
    end
  end
end
