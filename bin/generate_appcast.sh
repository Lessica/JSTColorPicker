#!/bin/bash

# Publish JSTColorPickerSparkle
APP_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
APP_BUILD_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
create-dmg --overwrite --identity='Developer ID Application: Zheng Wu (GXZ23M5TP2)' ./releases/apps/JSTColorPicker.app ./releases/apps/
mv ./releases/apps/*.dmg ./releases/JSTColorPicker_${APP_VERSION}-${APP_BUILD_VERSION}.dmg
./Pods/Sparkle/bin/generate_appcast --download-url-prefix https://cdn.82flex.com/jstcpweb/ -o ./releases/appcast.xml ./releases
scp -P 58422 ./releases/appcast.xml ubuntu@120.55.68.129:/var/www/html/jstcpweb

# Publish JSTColorPickerHelper
HELPER_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerHelper | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
HELPER_BUILD_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerHelper | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
zip -qr ./releases/helpers/JSTColorPickerHelper_${HELPER_VERSION}-${HELPER_BUILD_VERSION}.zip ./releases/helpers/JSTColorPickerHelper.app
