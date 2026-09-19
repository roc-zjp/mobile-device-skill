# Android 原生命令速查（adb）

`adb` 在 `~/Library/Android/sdk/platform-tools/adb`，不在默认 PATH。多设备时所有命令都要加 `-s <serial>`。

## 连接

```bash
adb devices -l                      # 列设备，state 必须是 device
adb kill-server && adb start-server # 设备识别不出来时第一招
adb -s <serial> reconnect           # 单台设备掉线重连

# 无线调试（Android 11+，先用 USB 连一次）
adb tcpip 5555 && adb connect <手机IP>:5555
# Android 11+ 的「无线调试」配对码方式，端口在开发者选项里看
adb pair <IP>:<配对端口>
```

设备显示 `unauthorized`：手机上没弹或没点「允许 USB 调试」，撤销授权后重插。
设备显示 `offline`：换线、换口，或 `adb kill-server`。

## 应用管理

```bash
adb install -r -d -t app.apk        # -r 覆盖 -d 允许降级 -t 允许 test 包
adb install-multiple base.apk split_*.apk   # AAB 拆出来的多 split
adb uninstall <包名>
adb uninstall -k <包名>             # 卸载但保留数据和缓存
adb shell pm clear <包名>           # 清数据，等价于"应用信息→清除数据"

adb shell pm list packages -3       # 只看第三方应用
adb shell pm list packages -s       # 只看系统应用
adb shell pm path <包名>            # 查 apk 在设备上的位置
adb shell dumpsys package <包名> | grep -E "versionName|versionCode|firstInstall"

adb shell am force-stop <包名>      # 强停
adb shell monkey -p <包名> -c android.intent.category.LAUNCHER 1   # 不知道 Activity 时启动
adb shell am start -n <包名>/<完整Activity>                        # 精确启动
adb shell am start -a android.intent.action.VIEW -d "myapp://path" # 深链
```

**查当前前台应用**（排查"这是哪个页面"最常用）：

```bash
adb shell dumpsys activity activities | grep -E "mResumedActivity|topResumedActivity"
adb shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp"
```

## 权限

```bash
adb shell pm grant <包名> android.permission.CAMERA
adb shell pm revoke <包名> android.permission.ACCESS_FINE_LOCATION
adb shell dumpsys package <包名> | grep -A40 "runtime permissions"
```

测「永久拒绝」路径：`revoke` 两次后系统会标记 `USER_FIXED`，或直接 `pm clear` 重置到首次安装状态。

## 日志

```bash
adb logcat -c                       # 先清缓冲区，否则全是历史噪音
adb logcat -v time                  # 带时间戳
adb logcat *:E                      # 只看 Error 及以上
adb logcat -s MyTag                 # 只看指定 tag
adb logcat --pid=$(adb shell pidof -s <包名>)   # 只看某应用的日志
adb logcat -b crash -d              # 崩溃缓冲区，-d 导出后退出
adb logcat -b all -d > full.log     # 全缓冲区落盘

adb shell dumpsys dropbox --print | head -100   # ANR / system crash 历史
adb pull /data/anr/traces.txt                   # ANR 线程栈（需权限）
```

Native crash 的 tombstone 在 `/data/tombstones/`，普通用户版设备拉不出来，看 logcat 里的 `DEBUG` tag 段落，配合 `ndk-stack` 符号化：

```bash
adb logcat | ndk-stack -sym <你的>/obj/local/arm64-v8a
```

## 截图录屏

```bash
adb exec-out screencap -p > shot.png      # 必须用 exec-out，shell 会破坏二进制流
adb shell screenrecord --time-limit 30 /sdcard/r.mp4 && adb pull /sdcard/r.mp4
adb shell screenrecord --size 720x1280 --bit-rate 4M /sdcard/r.mp4
```

`screenrecord` 最长 180 秒、不录音频、Ctrl+C 后要等一两秒文件才落盘完整。

## UI 操作与层级

```bash
adb shell input tap <x> <y>
adb shell input swipe <x1> <y1> <x2> <y2> [毫秒]      # 毫秒给长一点才是"滑动"而非"甩"
adb shell input text "hello"                          # 不支持中文和空格，空格用 %s
adb shell input keyevent KEYCODE_BACK                 # 3=HOME 4=BACK 26=POWER 82=MENU 66=ENTER
adb shell input keyevent --longpress 26

# 抓当前界面的 UI 层级，用来定位控件坐标
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml
```

打开指针位置显示（对坐标时很有用）：`adb shell settings put system pointer_location 1`

## 设备状态与调试开关

```bash
adb shell wm size / adb shell wm density        # 查分辨率和 DPI
adb shell wm size 1080x1920                     # 改（调完 wm size reset 还原）
adb shell dumpsys battery                       # 电量
adb shell dumpsys battery set level 15          # 造低电量场景，unplug 造拔电
adb shell dumpsys battery reset

adb shell settings put global window_animation_scale 0    # 关动画，UI 测试必备
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

adb shell svc wifi disable / enable             # 断网测试
adb shell svc data disable / enable
adb shell cmd netpolicy set restrict-background true      # 后台流量限制
```

## 性能

```bash
adb shell dumpsys gfxinfo <包名>                 # 掉帧统计，找 Janky frames
adb shell dumpsys meminfo <包名>                 # 内存，看 TOTAL PSS
adb shell dumpsys cpuinfo | head -20
adb shell top -m 10 -o %CPU,RES,NAME
adb shell am start -W -n <包名>/<Activity>       # 冷启动耗时，看 TotalTime
```

## 文件

```bash
adb push local.txt /sdcard/
adb pull /sdcard/remote.txt ./
adb shell ls /sdcard/Android/data/<包名>/files   # 应用外部目录
adb shell run-as <包名> ls files                  # debug 包才能进内部目录
```
