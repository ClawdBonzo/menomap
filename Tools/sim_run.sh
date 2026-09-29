#!/bin/zsh
# Build, install and launch MenoMap in the simulator with launch arguments.
# Usage: Tools/sim_run.sh [launch args...]   e.g. Tools/sim_run.sh -MMDemo -MMInMemory -MMPro -MMTab week
set -e
D=${MM_SIM:-F55486E3-0A89-45BC-A0C1-18831B7B5630}
DD=${MM_DD:-/tmp/claude-501/mm-dd}
cd "$(dirname "$0")/.."
xcodebuild -project MenoMap.xcodeproj -scheme MenoMap -destination "platform=iOS Simulator,id=$D" -derivedDataPath $DD build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u
xcrun simctl terminate $D app.gwlabs.menomap 2>/dev/null || true
xcrun simctl install $D $DD/Build/Products/Debug-iphonesimulator/MenoMap.app
xcrun simctl launch $D app.gwlabs.menomap "$@" >/dev/null && echo "launched $*"
