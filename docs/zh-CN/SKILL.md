---
name: mobile-device
description: 操作已连接的 Android / iOS 设备——截图、录屏、投屏镜像、装卸应用、启动应用、看实时日志、查崩溃日志、查设备信息。当用户说「截个图」「看看手机上现在什么样」「装一下这个包」「连了哪些设备」「看下日志」「崩溃了」「模拟器」「真机」「adb」「投屏」，或需要在真实设备上验证移动端改动时使用。覆盖 Android（adb/scrcpy）、iOS 模拟器（simctl）、iOS 真机（devicectl + pymobiledevice3）。不负责 UI 自动化点击（iOS 真机无此能力，见下文边界）。
---

# 移动设备操作

统一入口是 `mdev` 命令。它只做三件事：**发现设备、选中设备、把跨平台动词路由到原生命令**。长尾操作不在脚本里，直接查下面的速查表敲原生命令。

**如果 `mdev` 不在 PATH 里**（以插件方式安装、没跑过 `install.sh`），改调本 skill 目录下的 `scripts/mdev`，下面所有示例用法不变。

## 第一步永远是 `mdev ls`

```
$ mdev ls
ID   平台         名称                     系统      标识
--------------------------------------------------------------------------------
 a1  Android      Pixel 7                  14        2B141FDH2000TL
 i1  iOS 真机     iPad                     26.6.1    00008XXX-XXXXXXXXXXXXXXXX
 s1  iOS 模拟器   iPhone 17 Pro            26.0      5FCEE266-55BA-4F95-9E46-...
```

设备选择顺序：`-d 参数` > `MDEV_DEVICE` 环境变量 > `mdev use` 记住的 > **唯一在线设备自动选中**。
只有一台设备时什么都不用指定。多台时 `mdev use a1` 记住，或 `mdev -d i1 shot` 临时指定。
匹配支持短 ID、名称片段、UDID 前缀——`mdev -d Pixel shot` 和 `mdev -d a1 shot` 等价。

## 常用命令

| 命令 | 说明 |
|---|---|
| `mdev ls` / `mdev use <ID>` | 列设备 / 记住默认设备 |
| `mdev shot [-o out.png]` | 截图，默认存当前目录，**打印绝对路径后用 Read 看图** |
| `mdev rec [-o out.mp4] [-t 秒]` | 录屏（iOS 真机不支持） |
| `mdev mirror` | Android 起 scrcpy 可鼠标操作；模拟器唤起窗口 |
| `mdev info` | 型号、系统版本、分辨率、电量 |
| `mdev apps [-a]` | 列应用，默认只列用户应用 |
| `mdev install <apk/ipa/app>` | 按扩展名和设备平台自动校验 |
| `mdev uninstall / launch / stop <包名>` | 应用生命周期 |
| `mdev log [-g 关键词] [-c]` | 实时日志，`-c` 先清缓冲（仅 Android） |
| `mdev crash [--pull 目录]` | 崩溃日志，iOS 真机可拉取 .ips |
| `mdev url <deeplink>` | 打开深链（iOS 真机不支持） |
| `mdev shell <命令>` | 透传 adb shell，仅 Android |

## 典型工作流

**在真机上验证一处改动** —— 最常用的一条：

```bash
mdev install build.apk          # 按设备平台校验扩展名
mdev launch com.example.app
mdev shot                       # 打印绝对路径
```

然后**用 Read 打开打印出来的路径**。这一步才是真正「看见」界面的动作，也是最容易被跳过的一步。`launch` 回报 `Launched application` 只说明命令没报错——它不能说明界面渲染出来了、应用没在启动时崩掉、也不能说明有没有弹窗盖住整个屏幕。只有截图能。

**看某个应用现在是什么样**（不需要装包）：

```bash
mdev apps                       # 拿到准确的 bundle id / 包名，别猜
mdev launch <id>
mdev shot
```

**追一个崩溃：**

```bash
mdev crash                      # 最近的崩溃报告
mdev crash --pull ./crashes     # iOS 真机：把 .ips 文件拉到本地
mdev log -g <关键词>             # 或者实时抓，Ctrl+C 停止
```

**双端对比** —— 同一个界面，两台设备：

```bash
mdev ls
mdev -d a1 shot -o android.png
mdev -d i1 shot -o ios.png
```

把两个路径都 Read 出来并排看。

**iOS 真机截图前，屏幕必须已解锁亮起。** 锁屏状态下截图会「成功」并写出一张纯黑图。当 `mdev shot` 警告文件偏小时，让用户唤醒设备——不要循环重试，也不要去排查隧道。

## 能力边界（先看这张表，别试做不到的事）

| 能力 | Android | iOS 模拟器 | iOS 真机 |
|---|---|---|---|
| 截图 / 设备信息 / 应用列表 | ✅ | ✅ | ✅ |
| 装 / 卸 / 启动应用 | ✅ | ✅ `.app` | ✅ `.ipa`（需签名匹配） |
| 实时日志 / 崩溃日志 | ✅ | ✅ | ✅ |
| 录屏 | ✅ | ✅ | ❌ 只能 QuickTime 影片录制 |
| 投屏并用鼠标操作 | ✅ scrcpy | ✅ 原生窗口 | ❌ |
| 强停应用 | ✅ | ✅ | ❌ devicectl 只能启动不能杀 |
| 打开 deeplink | ✅ | ✅ | ❌ devicectl 无 open 子命令 |
| 点击 / 滑动 / 输入文本 | ✅ `adb input`（见 references/android.md） | ⚠️ 无原生 CLI | ❌ 需 WebDriverAgent，**已决定不做** |

**iOS 真机不做 UI 自动化是明确决策**，不是遗漏：WDA 要 Xcode 编译 + 证书签名（免费证书 7 天过期）+ 每台设备首次信任 + 测试进程常驻。需要点屏幕就上模拟器，或让用户手动操作后再截图确认。

## 三个会浪费时间的坑

**1. iOS 真机截图必须 `--userspace`，`--udid` 参数不存在。**
pymobiledevice3 10.x 的 `developer dvt` 走 iOS 17+ RemoteXPC 隧道，Device Options 只有 `--rsd` / `--tunnel` / `--userspace`，传 `--udid` 会报 "Device not found" 把人引向错误方向。`--userspace` 在进程内建用户态隧道，**不需要 sudo**，也不需要先起 tunneld，DDI 自动挂载，约 3 秒出图。
代价是它与 `--tunnel` 互斥，所以**多台 iOS 真机同时连接时无法指定截哪台**——此时先拔掉多余设备，或另起 `sudo pymobiledevice3 remote tunneld` 后用 `--tunnel <UDID>`。

**2. 熄屏截图会"成功"，但得到纯黑图。**
设备锁屏时截图返回 0、文件正常生成，只是全黑（约 44KB，远小于正常的几 MB）。`mdev shot` 已对偏小文件给出警告。看到警告先让用户解锁亮屏再截，别去怀疑工具或隧道。

**3. `devicectl list devices` 会列出历史配对过的所有设备。**
几十台 `unavailable` 的旧设备混在里面，只有 `connectionProperties.tunnelState == "connected"` 才是真正在线的。`mdev ls` 已做过滤。另外它的 JSON **只能写真实文件**，`--json-output /dev/stdout` 会拿到脏数据解析失败。

## 工具位置

`adb` 在 `~/Library/Android/sdk/platform-tools/`、`pymobiledevice3` 在 `~/.local/bin/`，**都不在默认 PATH 里**；脚本内部已自行定位，手敲原生命令时注意写全路径或先 `export PATH`。

## 速查表

原生命令长尾操作（改权限、模拟弱网、抓 UI 层级、模拟器状态栏、录制 Instruments 等）见：

- `references/android.md` — adb 全套
- `references/ios.md` — simctl / devicectl / pymobiledevice3 全套
