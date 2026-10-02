#!/bin/zsh
# usage: tools/run_sim.sh <args...>  -> builds Debug, installs, launches on the iPhone 17 Pro Max simulator
cd "$(dirname $0)/.."
SIM=E631CD4F-3293-4D70-A81F-453107BF207E
xcodebuild -project MirrorMatch.xcodeproj -scheme MirrorMatch -destination "platform=iOS Simulator,id=$SIM" -configuration Debug -derivedDataPath build/dd build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD" 
xcrun simctl boot $SIM 2>/dev/null; xcrun simctl bootstatus $SIM -b >/dev/null 2>&1
APP=$(find build/dd -name MirrorMatch.app -path "*Debug-iphonesimulator*" | head -1)
xcrun simctl install $SIM "$APP"
xcrun simctl terminate $SIM ch.connexa.mirrormatch 2>/dev/null
xcrun simctl launch $SIM ch.connexa.mirrormatch "$@"
