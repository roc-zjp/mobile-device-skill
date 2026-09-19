# Android cheat sheet (adb)

`adb` ships with the Android SDK platform-tools and is usually **not** on your PATH (`~/Library/Android/sdk/platform-tools/adb` on macOS). With more than one device attached every command needs `-s <serial>`.

## Connecting

```bash
adb devices -l                      # state must read "device"
adb kill-server && adb start-server # first thing to try when a device won't show up
adb -s <serial> reconnect

# Wireless debugging (Android 11+, pair over USB once first)
adb tcpip 5555 && adb connect <phone-ip>:5555
# Android 11+ pairing-code flow; the port is shown in Developer options
adb pair <ip>:<pairing-port>
```

`unauthorized` - the "Allow USB debugging" prompt was never accepted. Revoke authorizations in Developer options and replug.
`offline` - try another cable or port, or `adb kill-server`.

## Apps

```bash
adb install -r -d -t app.apk        # -r replace, -d allow downgrade, -t allow test packages
adb install-multiple base.apk split_*.apk   # split APKs produced from an AAB
adb uninstall <package>
adb uninstall -k <package>          # keep data and cache
adb shell pm clear <package>        # wipe data, same as "Clear storage" in Settings

adb shell pm list packages -3       # third-party only
adb shell pm list packages -s       # system only
adb shell pm path <package>         # where the APK sits on device
adb shell dumpsys package <package> | grep -E "versionName|versionCode|firstInstall"

adb shell am force-stop <package>
adb shell monkey -p <package> -c android.intent.category.LAUNCHER 1   # launch without knowing the Activity
adb shell am start -n <package>/<fully.qualified.Activity>
adb shell am start -a android.intent.action.VIEW -d "myapp://path"    # deep link
```

**Which screen am I looking at** - the single most useful pair of commands when debugging:

```bash
adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity"
adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp"
```

## Permissions

```bash
adb shell pm grant <package> android.permission.CAMERA
adb shell pm revoke <package> android.permission.ACCESS_FINE_LOCATION
adb shell dumpsys package <package> | grep -A40 "runtime permissions"
```

To reach the "permanently denied" state, revoke twice so the system marks it `USER_FIXED`, or `pm clear` to get back to a fresh-install state.

## Logs

```bash
adb logcat -c                       # clear first, otherwise you drown in history
adb logcat -v time
adb logcat *:E                      # errors and above
adb logcat -s MyTag
adb logcat --pid=$(adb shell pidof -s <package>)   # one app only
adb logcat -b crash -d              # crash buffer, -d dumps and exits
adb logcat -b all -d > full.log

adb shell dumpsys dropbox --print | head -100   # historical ANRs and system crashes
adb pull /data/anr/traces.txt                   # ANR thread dump (needs permission)
```

Native crash tombstones live in `/data/tombstones/` and are unreadable on production builds. Read the `DEBUG` tag section in logcat instead and symbolicate:

```bash
adb logcat | ndk-stack -sym <your-project>/obj/local/arm64-v8a
```

## Screenshots and recording

```bash
adb exec-out screencap -p > shot.png      # exec-out, NOT shell - shell corrupts the binary stream
adb shell screenrecord --time-limit 30 /sdcard/r.mp4 && adb pull /sdcard/r.mp4
adb shell screenrecord --size 720x1280 --bit-rate 4M /sdcard/r.mp4
```

`screenrecord` caps at 180 seconds, records no audio, and needs a second or two after Ctrl+C before the file is complete on device.

## Input and UI hierarchy

```bash
adb shell input tap <x> <y>
adb shell input swipe <x1> <y1> <x2> <y2> [ms]   # give it real duration or it registers as a fling
adb shell input text "hello"                     # no CJK, no spaces - use %s for a space
adb shell input keyevent KEYCODE_BACK            # 3=HOME 4=BACK 26=POWER 82=MENU 66=ENTER
adb shell input keyevent --longpress 26

adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml   # find element coordinates
```

Show touch coordinates on screen while working them out: `adb shell settings put system pointer_location 1`

## Device state and debug switches

```bash
adb shell wm size / adb shell wm density
adb shell wm size 1080x1920                     # `wm size reset` to restore

adb shell dumpsys battery
adb shell dumpsys battery set level 15          # fake a low battery; `unplug` fakes unplugging
adb shell dumpsys battery reset

adb shell settings put global window_animation_scale 0     # disable animations, essential for UI tests
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

adb shell svc wifi disable / enable             # offline testing
adb shell svc data disable / enable
adb shell cmd netpolicy set restrict-background true
```

## Performance

```bash
adb shell dumpsys gfxinfo <package>             # look for "Janky frames"
adb shell dumpsys meminfo <package>             # TOTAL PSS is the number you want
adb shell dumpsys cpuinfo | head -20
adb shell top -m 10 -o %CPU,RES,NAME
adb shell am start -W -n <package>/<Activity>   # cold start timing, read TotalTime
```

## Files

```bash
adb push local.txt /sdcard/
adb pull /sdcard/remote.txt ./
adb shell ls /sdcard/Android/data/<package>/files   # external app dir
adb shell run-as <package> ls files                  # internal dir, debuggable builds only
```
