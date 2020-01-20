Pod::Spec.new do |s|
    s.name             = 'vpncore'
    s.version          = '0.9.0'
    s.summary          = 'Core VPN components for use in ProtonVPN macOS and iOS apps'
    s.description      = 'Contains primatives, coordinators, services and extensions related to managing VPN connections.'
    s.homepage         = 'https://protonvpn.com'
    s.license          = { :type => 'GPL3', :file => 'LICENSE' }
    s.author           = { 'Proton Technologies AG' => 'contact@protonvpn.com' }
    s.source           = { :git => '', :tag => s.version.to_s }
    s.swift_version = '4.2'
    
    s.ios.deployment_target = '10.0'
    s.osx.deployment_target = '10.12'
    
    s.source_files = 'Source/*.swift', 'Source/*.sh'
    s.resource_bundle = { 'vpncore' => 'Source/Localization/*.lproj' }

    s.vendored_frameworks = 'Frameworks/*'
    
    s.dependency 'Alamofire', '~> 4.0'
    s.dependency 'KeychainAccess', '~> 3.0'
    s.dependency 'ReachabilitySwift', '~> 4.0'
    s.dependency 'Sentry', '~> 4.0'
    s.dependency 'TrustKit', '~> 1.0'
    
end
