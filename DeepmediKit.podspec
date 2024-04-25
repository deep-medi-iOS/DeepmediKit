#
# Be sure to run `pod lib lint DeepmediKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'DeepmediKit'
  s.version          = '1.4.0.2'
  s.summary          = 'Framework for measurement finger Tap or face'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

#  s.description      = <<-DESC
#TODO: Add long description of the pod here.
#                       DESC

  s.homepage         = 'https://github.com/deep-medi/DeepmediKit'
  s.license          = { :type => 'BSD', :file => 'LICENSE' }
  s.author           = { 'demianjun' => 'demianjun@gmail.com' }
  s.source           = { :git => 'https://github.com/deep-medi/DeepmediKit.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.source_files = 'DeepmediKit','DeepmediKit/Objc/*.{h,mm}', 'DeepmediKit/Classes/**/*.{h,swift}'
  s.resource_bundles = {'DeepmediKit' => ['DeepmediKit/Classes/PrivacyInfo.xcprivacy']}
  
  s.swift_versions = '5.0'
  s.static_framework = true
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  
  # s.resource_bundles = {
  #   'DeepmediFingerKit' => ['DeepmediFingerKit/Assets/*.png']
  # }
  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  
  s.dependency 'Then'
  s.dependency 'GoogleMLKit/FaceDetection'
  s.dependency 'Alamofire'
  s.dependency 'OpenCV'
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  # s.dependency 'Alamofire', '~> 5.2.0'
  # s.dependency 'RxSwift', '~> 6.0.0'
  # s.dependency 'RxCocoa', '~> 6.0.0'
  
end
