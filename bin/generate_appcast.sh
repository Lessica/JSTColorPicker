#!/bin/bash

set -e -x

mkdir -p ./releases/apps
mkdir -p ./releases/helpers

echo "Processing JSTColorPickerSparkle..."
APP_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerSparkle | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
APP_BUILD_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerSparkle | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
if [ -z "${APP_VERSION}" ]; then
    echo "Failed to fetch version from Xcode configuration."
    exit 1
fi
if [ -z "${APP_BUILD_VERSION}" ]; then
    echo "Failed to fetch version from Xcode configuration."
    exit 1
fi
APP_NAME="JSTColorPicker_${APP_VERSION}-${APP_BUILD_VERSION}.dmg"
create-dmg --overwrite --identity='Developer ID Application: Zheng Wu (GXZ23M5TP2)' ./releases/apps/JSTColorPicker.app ./releases/apps/
mv ./releases/apps/*.dmg ./releases/${APP_NAME}
./Pods/Sparkle/bin/generate_appcast --download-url-prefix https://cdn.82flex.com/jstcpweb/ -o ./releases/appcast.xml ./releases

echo "Processing JSTColorPickerHelper..."
HELPER_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerHelper | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
HELPER_BUILD_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerHelper | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
if [ -z "${HELPER_VERSION}" ]; then
    echo "Failed to fetch version from Xcode configuration."
    exit 1
fi
if [ -z "${HELPER_BUILD_VERSION}" ]; then
    echo "Failed to fetch version from Xcode configuration."
    exit 1
fi
HELPER_NAME="JSTColorPickerHelper_${HELPER_VERSION}-${HELPER_BUILD_VERSION}.zip"
HELPER_INCLUDED_FILE="return 302 https://cdn.82flex.com/jstcpweb/${HELPER_NAME};"
echo "${HELPER_INCLUDED_FILE}" > ./releases/nginx_latest_helper_redirect.txt
zip -qr ./releases/helpers/${HELPER_NAME} ./releases/helpers/JSTColorPickerHelper.app

echo "Upload resources..."
scp ./releases/${APP_NAME} root@120.55.68.129:/mnt/oss/jstcpweb/${APP_NAME}
scp ./releases/helpers/${HELPER_NAME} root@120.55.68.129:/mnt/oss/jstcpweb/${HELPER_NAME}

echo "Upload metadata..."
scp -P 58422 ./releases/appcast.xml ubuntu@120.55.68.129:/var/www/html/jstcpweb/appcast.xml

echo "Upload helper metadata..."
scp -P 58422 ./releases/nginx_latest_helper_redirect.txt ubuntu@120.55.68.129:/var/www/html/jstcpweb/nginx_latest_helper_redirect.txt
ssh -p 58422 root@120.55.68.129 nginx -t
ssh -p 58422 root@120.55.68.129 nginx -s reload
scp -rP 58422 ./releases/adhoc ubuntu@120.55.68.129:/var/www/html/jstcpweb/adhoc
