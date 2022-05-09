#!/bin/bash

set -e -x


CERT="Developer ID Application: Zheng Wu (GXZ23M5TP2)"
BUILD_ROOT=$(git rev-parse --show-toplevel)


cd "$BUILD_ROOT"
find . -name '.DS_Store' -type f -print -delete
mkdir -p releases/.app releases/.helper releases/.conf


APP_PATH="$BUILD_ROOT/releases/.app/JSTColorPicker.app"
APP_NAME="JSTColorPicker.dmg"

if [[ -d "$APP_PATH" ]]; then

    echo "Processing JSTColorPickerSparkle..."
    cd "$BUILD_ROOT"

    APP_VERSION=$(xcodebuild -showBuildSettings -target JSTColorPickerSparkle | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
    if [ -z "$APP_VERSION" ]; then
        echo "Failed to fetch version from Xcode configuration."
        exit 1
    fi

    APP_BUILD_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerSparkle | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
    if [ -z "$APP_BUILD_VERSION" ]; then
        echo "Failed to fetch version from Xcode configuration."
        exit 1
    fi

    APP_INCLUDED_FILE="return 302 https://cdn.82flex.com/jstcpweb/${APP_NAME};"
    echo "${APP_INCLUDED_FILE}" > releases/.conf/nginx_latest_app_redirect.txt

    create-dmg --overwrite --identity="$CERT" "$APP_PATH" releases/.app/

    APP_DMG_NAME="JSTColorPicker_$APP_VERSION-$APP_BUILD_VERSION.dmg"
    mv releases/.app/*.dmg releases/cdn/$APP_DMG_NAME

    Pods/Sparkle/bin/generate_appcast --download-url-prefix https://cdn.82flex.com/jstcpweb/ -o releases/appcast.xml releases/cdn

    trash "$APP_PATH"
fi


HELPER_PATH="$BUILD_ROOT/releases/.helper/JSTColorPickerHelper.app"
HELPER_NAME="JSTColorPickerScreenshotHelper.zip"

if [[ -d "$HELPER_PATH" ]]; then

    echo "Processing JSTColorPickerHelper..."
    cd "$BUILD_ROOT"

    HELPER_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerHelper | grep MARKETING_VERSION | tr -d 'MARKETING_VERSION =')
    if [ -z "${HELPER_VERSION}" ]; then
        echo "Failed to fetch version from Xcode configuration."
        exit 1
    fi

    HELPER_BUILD_VERSION=$(xcodebuild -disableAutomaticPackageResolution -showBuildSettings -target JSTColorPickerHelper | grep CURRENT_PROJECT_VERSION | tr -d 'CURRENT_PROJECT_VERSION =')
    if [ -z "${HELPER_BUILD_VERSION}" ]; then
        echo "Failed to fetch version from Xcode configuration."
        exit 1
    fi

    HELPER_INCLUDED_FILE="return 302 https://cdn.82flex.com/jstcpweb/${HELPER_NAME};"
    echo "${HELPER_INCLUDED_FILE}" > releases/.conf/nginx_latest_helper_redirect.txt

    HELPER_ZIP_NAME="JSTColorPickerHelper_${HELPER_VERSION}-${HELPER_BUILD_VERSION}.zip"
    cd releases/.helper/
    if [[ ! -f "${HELPER_ZIP_NAME}" ]]; then
        zip -qr "${HELPER_ZIP_NAME}" "JSTColorPickerHelper.app"
    fi
    mv "${HELPER_ZIP_NAME}" ../cdn/
    cd "$BUILD_ROOT"

    trash "$HELPER_PATH"
fi


echo "Upload resources..."
cd "$BUILD_ROOT"
rsync -avzP --no-perms --no-owner --no-group --exclude=".*" releases/cdn/ aliyun-nps:/mnt/oss/jstcpweb/


echo "Upload metadata..."
cd "$BUILD_ROOT"
scp releases/appcast.xml raspi-xtzn:/var/www/html/jstcpweb/appcast.xml


echo "Upload helper metadata..."
cd "$BUILD_ROOT"
scp releases/.conf/nginx_latest_*_redirect.txt raspi-xtzn:/var/www/html/jstcpweb/
ssh raspi-xtzn "nginx -t && nginx -s reload"


exit 0
