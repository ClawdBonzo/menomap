#!/bin/zsh
# Archive MenoMap (Release) and upload it to App Store Connect / TestFlight with the ASC API key.
# Usage: Tools/upload_build.sh   (bump CURRENT_PROJECT_VERSION in project.yml for every new upload)
set -e
cd "$(dirname "$0")/.."
AUTH=(-allowProvisioningUpdates -authenticationKeyPath ~/.private_keys/AuthKey_K34HFNJTXH.p8
      -authenticationKeyID K34HFNJTXH -authenticationKeyIssuerID 69a6de84-f289-47e3-e053-5b8c7c11a4d1)
ARCHIVE=build/MenoMap.xcarchive
rm -rf $ARCHIVE build/export
xcodebuild -project MenoMap.xcodeproj -scheme MenoMap -configuration Release -destination "generic/platform=iOS" \
  -archivePath $ARCHIVE archive $AUTH 2>&1 | grep -E "error:|warning: .*(sign|provision)|ARCHIVE (SUCCEEDED|FAILED)" | sort -u
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist Tools/ExportOptions.plist -exportPath build/export $AUTH 2>&1 \
  | grep -E "error|Upload|EXPORT (SUCCEEDED|FAILED)|uploaded" | sort -u
