#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint scanmynet_sdk.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'scanmynet_sdk'
  s.version          = '1.0.0'
  s.summary          = 'Flutter plugin for the ScanMyNet network diagnostics SDK.'
  s.description      = <<-DESC
Runs a full home-network scan through the native ScanMyNet SDK and returns a
structured diagnostics report to Flutter.
                       DESC
  s.homepage         = 'https://bitbucket.org/creativeadvtech/scanmynet_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'AAU' => 'info@aau.iq' }
  s.source           = { :path => '.' }
  s.source_files = 'scanmynet_sdk/Sources/scanmynet_sdk/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # The native ScanMyNet SDK, bundled as a prebuilt binary (the iOS counterpart
  # of the Android `tools` AAR). Rebuild it from scanmynet-ios via:
  #   xcodebuild archive -workspace ScanMyNet.xcworkspace -scheme Production \
  #     -configuration 'Production Release' (device + simulator) then
  #   xcodebuild -create-xcframework ... -output ScanMyNet.xcframework
  s.vendored_frameworks = 'ScanMyNet.xcframework'

  # Unlike the self-contained Android AARs, the iOS SDK is NOT standalone — it
  # links these third-party frameworks. They are all on the public CocoaPods
  # trunk, so the host app resolves them automatically during `pod install`.
  #
  # Versions are PINNED EXACTLY to what ScanMyNet.xcframework was compiled
  # against (scanmynet-ios/Podfile.lock). A precompiled Swift binary links
  # against specific symbol/witness tables, so even a patch bump (e.g. Alamofire
  # 5.11.1 -> 5.11.2) drops a symbol and crashes at launch with a dyld
  # "Symbol not found" error. Bump these only in lockstep with a framework
  # rebuilt against the new versions.
  s.dependency 'Alamofire', '5.11.1'
  s.dependency 'BlueSocket', '2.0.4'
  s.dependency 'NDT7', '0.0.4'
  s.dependency 'XMLCoder', '0.13.1'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'scanmynet_sdk_privacy' => ['scanmynet_sdk/Sources/scanmynet_sdk/PrivacyInfo.xcprivacy']}
end
