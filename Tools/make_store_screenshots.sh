#!/bin/zsh
# App Store screenshots, end to end:  Tools/make_store_screenshots.sh [en de ja …]
# 1. iPhone 17 Pro Max (6.9", 1320×2868), light mode, 9:41 status bar.
# 2. Captures 9 raw frames per language via launch arguments (demo data, frozen hour, no tapping).
# 3. make_store_screenshots.swift composes the marketing frames (headline + real UI).
set -e
cd "$(dirname "$0")/.."
UDID=${MM_SHOT_SIM:-BD99E24A-6C24-4428-A5F4-5D78FAB19218}
DD=${MM_DD:-/tmp/claude-501/mm-dd}
WORK=build/store
LANGS=(${@:-en en-GB})
xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl bootstatus $UDID -b >/dev/null
xcrun simctl ui $UDID appearance light
xcrun simctl status_bar $UDID override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcodebuild -project MenoMap.xcodeproj -scheme MenoMap -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath $DD build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u
xcrun simctl install $UDID $DD/Build/Products/Debug-iphonesimulator/MenoMap.app
typeset -A LOCALE=(en en_US en-GB en_GB de de_DE fr fr_FR es es_ES es-419 es_MX ja ja_JP ko ko_KR it it_IT nl nl_NL pt-BR pt_BR pt-PT pt_PT
  sv sv_SE da da_DK nb nb_NO fi fi_FI pl pl_PL zh-Hant zh_TW zh-Hans zh_SG he he_IL ar ar_SA tr tr_TR cs cs_CZ sk sk_SK hu hu_HU ro ro_RO
  hr hr_HR el el_GR uk uk_UA th th_TH vi vi_VN id id_ID ms ms_MY hi hi_IN)
FRAMES=(
  "01|-MMDemo -MMPro"
  "02|-MMDemo -MMPro -MMShowcase nightwatch"
  "03|-MMDemo -MMPro -MMTab week -MMRange 30"
  "04|-MMDemo -MMPro -MMShowcase patterns"
  "05|-MMDemo -MMPro -MMShowcase pdf"
  "06|-MMOnboardingStep health"
  "07|-MMDemo -MMPro -MMShowcase watch"
  "08|-MMDemo -MMPro -MMShowcase experiment"
  "09|-MMDemo -MMPro -MMShowcase privacy"
)
for L in $LANGS; do
  mkdir -p $WORK/raw/$L
  for F in $FRAMES; do
    N=${F%%|*}; ARGS=(${=F#*|})
    xcrun simctl terminate $UDID app.gwlabs.menomap 2>/dev/null || true
    xcrun simctl launch $UDID app.gwlabs.menomap -MMInMemory -MMHour 14 -AppleLanguages "($L)" -AppleLocale ${LOCALE[$L]:-en_US} $ARGS >/dev/null
    sleep 4
    xcrun simctl io $UDID screenshot $WORK/raw/$L/$N.png >/dev/null 2>&1
  done
  echo "captured $L"
done
python3 Tools/store_frames.py "${LANGS[@]}" > $WORK/frames.json
swift Tools/make_store_screenshots.swift $WORK/frames.json $WORK/raw $WORK/composed
xcrun simctl status_bar $UDID clear
