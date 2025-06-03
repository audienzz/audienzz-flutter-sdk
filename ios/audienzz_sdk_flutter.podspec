Pod::Spec.new do |s|
  s.name             = 'audienzz_sdk_flutter'
  s.version          = '0.0.2'
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
  s.dependency 'Google-Mobile-Ads-SDK','12.3.0'
  s.dependency 'AudienzziOSSDK', '0.0.23'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
