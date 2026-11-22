#!/bin/zsh
# 協調者每個任務用的查證腳本：analyze、test、網頁自我測試、assets 是否同步、兩個平台建置；加 --launch 會在兩個模擬器上安裝並啟動。
# 換機器時，先把下面的 AVD 名稱與 iOS 模擬器（iPhone 17、iOS 27.0）改成 docs/ENVIRONMENT.md 記錄的裝置。
# 用法：zsh docs/handoff/verify.sh [--launch]
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP=$ROOT/flutter_app
SDK=$HOME/Library/Android/sdk
ADB=$SDK/platform-tools/adb
ANDROID_ID=com.example.a11ydemo.a11y_webview_demo
IOS_ID=com.example.a11ydemo.a11yWebviewDemo
cd $APP || exit 1

echo "== analyze"; flutter analyze 2>&1 | tail -3; echo "exit=${pipestatus[1]}"
echo "== test"; flutter test 2>&1 | tail -3; echo "exit=${pipestatus[1]}"
echo "== node"; (cd $ROOT && node web/test/run.mjs 2>&1 | tail -3; echo "exit=${pipestatus[1]}")
if [ -x tool/sync_web.sh ]; then echo "== assets in sync?"; diff -rq -x .DS_Store $ROOT/web assets/web >/dev/null && echo "in sync" || echo "OUT OF SYNC"; fi
echo "== apk"; flutter build apk --debug 2>&1 | tail -2; echo "exit=${pipestatus[1]}"
echo "== ios"; flutter build ios --simulator --debug 2>&1 | tail -2; echo "exit=${pipestatus[1]}"

if [ "${1:-}" = "--launch" ]; then
  echo "== android launch"
  $SDK/emulator/emulator -avd Pixel_4_API_32 -no-window -no-audio -no-boot-anim -no-snapshot-save > ${TMPDIR:-/tmp}/a11y-emulator.log 2>&1 &
  EMUPID=$!
  booted=0
  for i in $(seq 1 60); do
    sleep 5
    kill -0 $EMUPID 2>/dev/null || { echo "emulator exited early"; break; }
    [ "$($ADB -e shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && { booted=1; break; }
  done
  echo "booted=$booted"
  if [ $booted = 1 ]; then
    $ADB -e install -r build/app/outputs/flutter-apk/app-debug.apk 2>&1 | tail -1
    $ADB -e logcat -c
    $ADB -e shell monkey -p $ANDROID_ID -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 10
    echo "pid=$($ADB -e shell pidof $ANDROID_ID | tr -d '\r')"
    echo "fatal/exception lines: $($ADB -e logcat -d 2>/dev/null | grep -c -E "FATAL EXCEPTION|E/flutter")"
    $ADB -e logcat -d 2>/dev/null | grep -E "FATAL EXCEPTION|E/flutter" | head -5
    $ADB -e exec-out screencap -p > ${TMPDIR:-/tmp}/a11y-android.png 2>/dev/null && echo "screenshot ${TMPDIR:-/tmp}/a11y-android.png"
    $ADB -e uninstall $ANDROID_ID 2>&1 | tail -1
    $ADB -e emu kill >/dev/null 2>&1; sleep 4
  fi
  kill $EMUPID 2>/dev/null

  echo "== ios launch"
  UDID=$(xcrun simctl list devices available -j | python3 -c '
import json,sys
d=json.load(sys.stdin)["devices"]
for rt,devs in d.items():
    if rt.endswith("iOS-27-0"):
        for x in devs:
            if x["name"]=="iPhone 17": print(x["udid"]); sys.exit()
')
  echo "udid=$UDID"
  xcrun simctl boot $UDID 2>&1 | tail -1
  xcrun simctl bootstatus $UDID -b >/dev/null 2>&1
  xcrun simctl install $UDID build/ios/iphonesimulator/Runner.app 2>&1 | tail -1
  xcrun simctl launch $UDID $IOS_ID 2>&1 | tail -1
  sleep 8
  xcrun simctl io $UDID screenshot ${TMPDIR:-/tmp}/a11y-ios.png >/dev/null 2>&1 && echo "screenshot ${TMPDIR:-/tmp}/a11y-ios.png"
  xcrun simctl spawn $UDID launchctl list 2>/dev/null | grep -c "$IOS_ID" | sed 's/^/running entries=/'
  xcrun simctl uninstall $UDID $IOS_ID 2>&1 | tail -1
  xcrun simctl shutdown $UDID 2>&1 | tail -1
fi
echo "== git status"; git -C $ROOT status --short | head -10
echo "== done"
