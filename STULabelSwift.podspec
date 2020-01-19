Pod::Spec.new do |s|
  s.name     = 'STULabelSwift'
  s.version  = '0.8.5'
  s.dependency 'STULabel', "~> 0.8.5"
  
  s.swift_version = '4.2'
  s.platform = :ios, '9.3'

  s.license  = { :type => '2-clause BSD', :file => 'LICENSE.txt' }

  s.homepage = 'https://github.com/stephan-tolksdorf/STULabel'
  s.source = { :git => 'https://github.com/stephan-tolksdorf/STULabel.git', :tag => "#{s.version}" }
  s.author = { 'Stephan Tolksdorf' => 'stulabel@quanttec.com' }
  s.social_media_url = 'https://twitter.com/s_tolksdorf'

  s.summary = 'A faster and more flexible label view for iOS'
  
  s.source_files = 'STULabelSwift/**/*.swift'

  s.prefix_header_file = false
  
  s.pod_target_xcconfig = { 
    'SWIFT_INSTALL_OBJC_HEADER' => 'NO'
  }
end
