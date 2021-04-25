#!/bin/bash

# Publish JSTColorPickerSparkle
APP_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
APP_BUILD_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
create-dmg --overwrite --identity='Developer ID Application: Zheng Wu (GXZ23M5TP2)' ./releases/Applications/JSTColorPicker.app ./releases/Applications/
mv ./releases/Applications/*.dmg ./releases/JSTColorPicker_${APP_VERSION}-${APP_BUILD_VERSION}.dmg
./Pods/Sparkle/bin/generate_appcast --download-url-prefix https://cdn.82flex.com/jstcpweb/ -o ./releases/appcast.xml ./releases
scp ./releases/appcast.xml ubuntu@xtzn-raspi.local:/var/www/html/jstcpweb

# Publish JSTColorPickerHelper
HELPER_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerHelper | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
HELPER_BUILD_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerHelper | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
zip -qr ./releases/Helpers/JSTColorPickerHelper_${HELPER_VERSION}-${HELPER_BUILD_VERSION}.zip ./releases/Helpers/JSTColorPickerHelper.app
