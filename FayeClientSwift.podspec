#
# Be sure to run `pod lib lint FayeClientSwift.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
    s.name             = 'FayeClientSwift'
    s.version          = '0.2.0'
    s.summary          = 'A Faye Cilent in Swift for iOS and OSX.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

s.description      = <<-DESC
    A Faye Cilent Library in Swift for the Faye (Bayeux) Pub-Sub messaging server.
    Use the library to communicate with a Faye Server (https://faye.jcoglan.com) implementation of the Bayeux protocol.
    Websocket transport supported.
                        DESC

    s.homepage         = 'https://github.com/Binlogo/FayeClientSwift'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Binboy_王兴彬' => 'binboy@live.com' }
    s.source           = { :git => 'https://github.com/Binlogo/FayeClientSwift.git', :tag => s.version.to_s }
    s.social_media_url = 'https://weibo.com/binlogo'

    s.osx.deployment_target = "10.10"
    s.ios.deployment_target = '8.0'
    s.tvos.deployment_target = "9.0"

    s.source_files = 'Classes/*.swift'

    s.dependency 'Starscream', '~> 2.0'
end
