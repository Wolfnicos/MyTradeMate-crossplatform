#!/bin/zsh
set -euo pipefail

# Resolve project directory to this script's location
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Absolute tool paths on this machine
ANDROID_SDK="/Users/lupudragos/Library/Android/sdk"
EMULATOR_BIN="$ANDROID_SDK/emulator/emulator"
ADB_BIN="$ANDROID_SDK/platform-tools/adb"
FLUTTER_BIN="/Users/lupudragos/flutter/bin/flutter"

if [ ! -x "$FLUTTER_BIN" ]; then
  echo "flutter not found at $FLUTTER_BIN, falling back to flutter in PATH"
  FLUTTER_BIN="flutter"
fi

# Choose AVD: prefer MyTradeMate_Pixel7, fallback to first available
AVD_NAME="MyTradeMate_Pixel7"
if ! "$EMULATOR_BIN" -list-avds | grep -qx "$AVD_NAME"; then
  AVD_NAME="$($EMULATOR_BIN -list-avds | head -n1)"
fi

# If no emulator is running, start one
DEVICE="$($ADB_BIN devices | awk 'NR>1 && $1 ~ /emulator-/ && $2=="device"{print $1}' | head -n1)"
if [ -z "${DEVICE:-}" ]; then
  echo "Starting emulator: $AVD_NAME ..."
  nohup "$EMULATOR_BIN" -avd "$AVD_NAME" -netdelay none -netspeed full >/dev/null 2>&1 &
  echo "Waiting for emulator to boot..."
  "$ADB_BIN" wait-for-device
  for i in {1..120}; do
    if "$ADB_BIN" shell getprop sys.boot_completed | tr -d '\r' | grep -q '1'; then
      break
    fi
    sleep 2
  done
  DEVICE="$($ADB_BIN devices | awk 'NR>1 && $1 ~ /emulator-/ && $2=="device"{print $1}' | head -n1)"
fi

if [ -z "${DEVICE:-}" ]; then
  echo "No Android emulator/device available. Aborting." >&2
  exit 1
fi

echo "Using device: $DEVICE"

"$FLUTTER_BIN" pub get

# If NONINTERACTIVE=1, build+install+launch without attaching. Otherwise attach with flutter run.
if [ "${NONINTERACTIVE:-0}" = "1" ]; then
  echo "Building debug APK..."
  "$FLUTTER_BIN" build apk --debug
  echo "Installing APK on $DEVICE..."
  "$ADB_BIN" install -r "$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
  echo "Launching app..."
  "$ADB_BIN" shell am start -n com.example.mytrademate/.MainActivity
  echo "Done. App launched on $DEVICE."
else
  "$FLUTTER_BIN" run -d "$DEVICE"
fi


