Pod::Spec.new do |s|
  s.name             = "Signature"
  s.summary          = "UIView with signature support"
  s.version          = "0.2.0"
  s.homepage         = "https://github.com/hyperoslo/Signature"
  s.license          = 'MIT'
  s.author           = { "Hyper Interaktiv AS" => "ios@hyper.no" }
  s.source           = { :git => "https://github.com/hyperoslo/Signature.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/hyperoslo'
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Source/**/*'
  s.frameworks = 'UIKit', 'GLKit'
end
