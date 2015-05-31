Pod::Spec.new do |s|
  s.name             = "ImageCaptureSession"
  s.version          = "1.0.1"
  s.summary          = "An easy way to resize a gif."
  s.homepage         = "https://github.com/gbarcena/ImageCaptureSession"
  s.license          = 'MIT'
  s.author           = { "Gustavo" => "gustavo@barcena.me" }
  s.source           = { :git => "https://github.com/gbarcena/ImageCaptureSession.git", :tag => s.version.to_s }

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'ImageCaptureSession/Source/*'

  s.frameworks = 'UIKit', 'MobileCoreServices', 'ImageIO'
end
