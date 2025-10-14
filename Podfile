workspace 'TuneURL.xcworkspace'
platform :ios, '15.0'
use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

install! 'cocoapods',
         :generate_multiple_pod_projects => true,
         :incremental_installation => true

target 'TuneURL' do
    pod 'Alamofire'
    pod 'DMSwipeCards'
end

# MARK: - PODS BUIDS SETTINGS CONFIGURATION
post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
        config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
        config.build_settings['ARCHS'] = '$(ARCHS_STANDARD)'
        config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
        
        config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
        config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
        config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
        
        if config.name == 'Debug'
          config.build_settings['OTHER_SWIFT_FLAGS'] = ['$(inherited)', '-Onone']
          config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Owholemodule'
        end
      end
    end
  end
end
