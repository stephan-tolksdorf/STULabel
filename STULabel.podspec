Pod::Spec.new do |s|
  s.name     = 'STULabel'
  s.version  = '0.8.9'

  s.cocoapods_version = '>= 1.5.0'

  s.platform = :ios, '9.3'

  s.license  = { :type => '2-clause BSD', :file => 'LICENSE.txt' }

  s.homepage = 'https://github.com/stephan-tolksdorf/STULabel'
  s.source = { :git => 'https://github.com/stephan-tolksdorf/STULabel.git', :tag => "#{s.version}" }
  s.author = { 'Stephan Tolksdorf' => 'stulabel@quanttec.com' }
  s.social_media_url = 'https://twitter.com/s_tolksdorf'

  s.summary = 'A faster and more flexible label view for iOS'
  
  s.module_map = 'STULabel/STULabel.modulemap'
  s.source_files = 'STULabel/**/*.{h,hpp,m,mm,c,cpp}'
  s.public_header_files = Dir.glob('STULabel/*.h') - Dir.glob('STULabel/*-Internal.*')
  s.requires_arc = Dir.glob('STULabel/**/*.{m,mm}') - Dir.glob('STULabel/**/*-no-ARC.*')
  s.resource_bundles = {'STULabelResources' => 'STULabel/Resources/**/*.strings' }
  
  s.library = 'c++'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES',
    'GCC_SYMBOLS_PRIVATE_EXTERN' => 'YES',
    'ALWAYS_SEARCH_USER_PATHS' => 'NO',
    'USE_HEADERMAP' => 'NO',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}" "${PODS_TARGET_SRCROOT}/STULabel/Internal"', 
    
    'GCC_C_LANGUAGE_STANDARD' => 'gnu11',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'CLANG_CXX_LIBRARY' => 'libc++',

    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) STU_IMPLEMENTATION=1 STU_USE_SAFARI_SERVICES=1',

    'WARNING_CFLAGS' => '$(inherited) -Wno-unused-command-line-argument -Wno-missing-braces -Wno-nullability-completeness',

    'GCC_ENABLE_CPP_RTTI' => 'NO',

    'STU_CONFIGURATION_Debug' => 'DEBUG',
    'STU_CONFIGURATION' => '$(STU_CONFIGURATION_$(CONFIGURATION))',

    'STU_GCC_ENABLE_CPP_EXCEPTIONS_' => 'NO',
    'STU_GCC_ENABLE_CPP_EXCEPTIONS_DEBUG' => 'YES',
    
    'GCC_ENABLE_CPP_EXCEPTIONS' => '$(STU_GCC_ENABLE_CPP_EXCEPTIONS_$(STU_CONFIGURATION))',

    'STU_OTHER_CPLUSPLUSFLAGS_' => '-fno-objc-exceptions -fno-objc-arc-exceptions',
    'STU_OTHER_CPLUSPLUSFLAGS_DEBUG' => '',
    
    'OTHER_CPLUSPLUSFLAGS' => '-UNDEBUG -fcxx-modules $(STU_OTHER_CPLUSPLUSFLAGS_$(STU_CONFIGURATION))'
  }
end