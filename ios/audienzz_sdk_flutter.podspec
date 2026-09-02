Pod::Spec.new do |s|
  s.name             = 'audienzz_sdk_flutter'
  s.version          = '0.1.9'
  s.summary          = 'Flutter wrapper for Audienzz Mobile SDK'
  s.description      = <<-DESC
Flutter wrapper for Audienzz Mobile SDK
                       DESC
  s.homepage         = 'https://audienzz.com/'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Audienzz' => 'service@audienzz.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # AudienzziOSSDK 0.3.0 requires Google-Mobile-Ads-SDK 13 and uses
  # PrebidMobile's UserUniqueID(uniqueId:) (3.3.1+); GMAS 13 raises the min iOS
  # deployment target to 15. 0.3.0 builds against stock PrebidMobile (no fork).
  s.dependency 'Google-Mobile-Ads-SDK', '~> 13.0'
  s.dependency 'AudienzziOSSDK', '~> 0.3.0'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
