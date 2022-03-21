platform :osx, '10.15'
project 'JSTColorPicker'
use_frameworks!
inhibit_all_warnings!

target :JSTColorPicker do
  pod 'AppCenter'
  pod 'SwiftyStoreKit'
	pod 'MASPreferences', :git => 'git@github.com:Lessica/MASPreferences.git'
  pod 'DynamicCodable', '1.0'
end

target :JSTColorPickerSparkle do
  pod 'AppCenter'
	pod 'Sparkle'
  pod 'LetsMove'
	pod 'MASPreferences', :git => 'git@github.com:Lessica/MASPreferences.git'
  pod 'DynamicCodable', '1.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
      config.build_settings.delete 'ARCHS'
    end
  end
end
