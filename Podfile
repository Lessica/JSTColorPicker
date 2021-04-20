platform :osx, '11.0'
project 'JSTColorPicker.xcodeproj'
use_frameworks!
inhibit_all_warnings!

target :JSTColorPicker do
  pod 'SwiftyStoreKit'
	pod 'PromiseKit/CorePromise'
	pod 'MASPreferences', :git => 'git@github.com:Lessica/MASPreferences.git'
end

target :JSTColorPickerSparkle do
	pod 'Sparkle'
  pod 'LetsMove'
	pod 'PromiseKit/CorePromise'
	pod 'MASPreferences', :git => 'git@github.com:Lessica/MASPreferences.git'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      config.build_settings.delete 'ARCHS'
    end
  end
end
