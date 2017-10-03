Pod::Spec.new do |s|
  s.name             = "GRKSignatureView"
  s.summary          = "A UIView subclass used to capture a high quality rendition of a user's signature."
  s.description  = <<-DESC
Allows touch input of a signature or other handwriting, with smoothed lines and thickness,
and capturing of same as an image.
    DESC
  s.version          = "1.0"
  s.homepage         = "https://github.com/levigroker/GRKSignatureView"
  s.license          = 'Creative Commons Attribution 4.0 International License'
  s.author           = { "Levi Brown" => "levigroker@gmail.com" }
  s.social_media_url = 'https://twitter.com/levigroker'
  s.source           = { :git => "https://github.com/levigroker/GRKSignatureView.git", :tag => s.version.to_s }
  s.platform         = :ios, '9.0'
  s.frameworks       = 'UIKit', 'GLKit'
  s.source_files     = ['GRKSignatureView/*.{h,m}']
end
