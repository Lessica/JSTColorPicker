#!/bin/bash

set -e -x

find . -name '.DS_Store' -type f -print -delete

mkdir -p ./releases/apps
mkdir -p ./releases/helpers
mkdir -p ./releases/conf

echo "Processing JSTColorPickerSparkle..."
APP_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
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
echo "${HELPER_INCLUDED_FILE}" > ./releases/conf/nginx_latest_helper_redirect.txt
cd ./releases/helpers/
zip -qr ${HELPER_NAME} JSTColorPickerHelper.app
cd ../../

echo "Upload resources..."
scp ./releases/${APP_NAME} aliyun-nps:/mnt/oss/jstcpweb/${APP_NAME}
scp ./releases/*.delta aliyun-nps:/mnt/oss/jstcpweb/
scp ./releases/helpers/${HELPER_NAME} aliyun-nps:/mnt/oss/jstcpweb/${HELPER_NAME}

echo "Upload metadata..."
scp ./releases/appcast.xml raspi-xtzn:/var/www/html/jstcpweb/appcast.xml

echo "Upload helper metadata..."
scp ./releases/conf/nginx_latest_helper_redirect.txt raspi-xtzn:/var/www/html/jstcpweb/nginx_latest_helper_redirect.txt
ssh raspi-xtzn nginx -t
ssh raspi-xtzn nginx -s reload
scp -r ./releases/adhoc raspi-xtzn:/var/www/html/jstcpweb/adhoc
