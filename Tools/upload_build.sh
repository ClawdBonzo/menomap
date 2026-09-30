#!/bin/zsh
# Archive MenoMap (Release) and upload it to App Store Connect / TestFlight.
# Signing and upload use the Apple account signed in to Xcode: the ASC API key fails Xcode's cloud signing
# ("Authentication failed: bearer token"), so it's only used for App Store Connect API calls.
# Usage: Tools/upload_build.sh   (bump CURRENT_PROJECT_VERSION in project.yml for every new upload)
set -e
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
AUTH=(-allowProvisioningUpdates)
ARCHIVE=build/MenoMap.xcarchive
rm -rf $ARCHIVE build/export
xcodebuild -project MenoMap.xcodeproj -scheme MenoMap -configuration Release -destination "generic/platform=iOS" \
  -archivePath $ARCHIVE archive $AUTH 2>&1 | grep -E "error:|warning: .*(sign|provision)|ARCHIVE (SUCCEEDED|FAILED)" | sort -u
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist Tools/ExportOptions.plist -exportPath build/export $AUTH 2>&1 \
  | grep -E "error|Upload|EXPORT (SUCCEEDED|FAILED)|uploaded" | sort -u
