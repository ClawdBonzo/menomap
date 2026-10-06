#!/bin/zsh
# Archive MenoMap (Release) and upload it to App Store Connect / TestFlight.
# The archive signs with the local Apple Distribution certificate. Export/upload authenticates with the ASC API key,
# because Xcode's signed-in account session lapses (it did when the team moved to GW Capital Partners LLC).
# Usage: Tools/upload_build.sh   (bump CURRENT_PROJECT_VERSION in project.yml for every new upload)
set -e
cd "$(dirname "$0")/.."
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
AUTH=(-allowProvisioningUpdates)
ARCHIVE=build/MenoMap.xcarchive
rm -rf $ARCHIVE build/export
xcodebuild -project MenoMap.xcodeproj -scheme MenoMap -configuration Release -destination "generic/platform=iOS" \
  -archivePath $ARCHIVE archive $AUTH 2>&1 | grep -E "error:|warning: .*(sign|provision)|ARCHIVE (SUCCEEDED|FAILED)" | sort -u
KEY=(-authenticationKeyPath ~/.private_keys/AuthKey_K34HFNJTXH.p8 -authenticationKeyID K34HFNJTXH
     -authenticationKeyIssuerID 69a6de84-f289-47e3-e053-5b8c7c11a4d1)
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist Tools/ExportOptions.plist -exportPath build/export $AUTH $KEY 2>&1 \
  | grep -E "error|Upload|EXPORT (SUCCEEDED|FAILED)|uploaded" | sort -u
# Every app sends each new build to Rob's TestFlight automatically (internal group with automatic distribution).
python3 Tools/testflight_autosend.py | grep -v " ok (" || true
