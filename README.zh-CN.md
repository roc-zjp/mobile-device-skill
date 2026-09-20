# mdev

**一条命令操作 Android 和 iOS 设备。** 截图、录屏、投屏、装包、启动、看日志、抓崩溃——不必再记哪件事归四个工具里的哪一个管。

[English](README.md)

```console
$ mdev ls
ID   平台         名称                     系统      标识
--------------------------------------------------------------------------------
 a1  Android      Pixel 7                  14        2B141FDH2000TL
 i1  iOS 真机     iPad                     26.6.1    00008XXX-XXXXXXXXXXXXXXXX
 s1  iOS 模拟器   iPhone 17 Pro            26.0      5FCEE266-55BA-4F95-9E46-...

$ mdev shot
* /Users/you/work/Pixel7-0919-141211.png  (1.4 MB)
```

## 为什么要有它

从终端操作移动设备，要同时对付四个各有脾气的工具：

- `adb` 管 Android，且默认不在 PATH 里
- `xcrun simctl` 管 iOS 模拟器
- `xcrun devicectl` 管 iOS 真机——但它没有截图功能
- `pymobiledevice3` 管 iOS 真机的截图和日志——隧道模型的报错极具误导性

`mdev` 是这四者之上的一层薄路由：发现设备、选中设备、把一个动词派发到正确的原生命令。**它刻意不包装所有功能**——长尾操作留在[速查表](docs/zh-CN/)里，因为一个还要专门学的包装层，比你本来就会的命令更糟。

## 安装

需要 Python 3.8+。平台工具按需安装，只用哪端就装哪端。

**作为 CLI**（同时装上 skill；你想自己敲 `mdev` 就选这条）：

```bash
git clone https://github.com/roc-zjp/mobile-device-skill.git
cd mobile-device-skill
./install.sh
```

`install.sh` 把 `mdev` 软链到 `~/.local/bin`，并询问是否把 skill 软链到 `~/.claude/skills`。全程软链不复制，所以 `git pull` 就能就地更新。

**作为 Claude Code 插件：**

```
/plugin marketplace add roc-zjp/mobile-device-skill
/plugin install mobile-device
```

这样 AI 拿到了 skill，但 `mdev` 不会进你自己的 PATH——代理是按路径调脚本的。想自己也能用这个命令，在插件安装目录下跑一次 `./install.sh`。

按需安装的前置：

| 用途 | 安装 |
|---|---|
| Android | Android SDK platform-tools（`adb`） |
| Android 投屏 | `brew install scrcpy` |
| iOS 模拟器 | Xcode 命令行工具 |
| iOS 真机 | Xcode + `pipx install pymobiledevice3` |

## 使用

```bash
mdev ls                      # 连了什么
mdev use a1                  # 记住默认设备
mdev shot                    # 截图到当前目录
mdev shot -d i1 -o /tmp/x.png
mdev rec -t 30               # 录 30 秒
mdev mirror                  # Android 起 scrcpy，iOS 唤起模拟器窗口
mdev info                    # 型号、系统、分辨率、电量
mdev apps                    # 已装应用（-a 含系统应用）
mdev install build.apk       # 按设备平台校验扩展名
mdev launch com.example.app
mdev log -g Crash            # 实时日志，带过滤
mdev crash --pull ./crashes  # 从 iOS 真机拉 .ips 文件
mdev shell getprop           # 透传 adb shell
```

**设备选择**顺序是 `-d` > `MDEV_DEVICE` > `mdev use` 记住的 > 唯一在线设备。只有一台时什么都不用指定。`-d` 接受短 ID（`a1`）、名称片段（`Pixel`）或 UDID 前缀，放在子命令前后都认。

**输出语言**跟随系统 locale，用 `MDEV_LANG=zh` 或 `MDEV_LANG=en` 可强制指定。

## 能力矩阵

动手前先看这张表，别试做不到的事：

| | Android | iOS 模拟器 | iOS 真机 |
|---|:---:|:---:|:---:|
| 截图 | ✅ | ✅ | ✅ |
| 设备信息 / 应用列表 | ✅ | ✅ | ✅ |
| 装 / 卸 / 启动 | ✅ | ✅ `.app` | ✅ `.ipa` |
| 实时日志 / 崩溃日志 | ✅ | ✅ | ✅ |
| 录屏 | ✅ | ✅ | ❌ 只能 QuickTime |
| 投屏 + 鼠标操作 | ✅ scrcpy | ✅ | ❌ |
| 强停应用 | ✅ | ✅ | ✅ |
| 打开深链 | ✅ | ✅ | ❌ |
| 点击 / 滑动 / 输入 | ✅ `adb input` | ❌ 无原生 CLI | ❌ 需 WebDriverAgent |

**iOS 真机的 UI 自动化是刻意不做，不是遗漏。** WebDriverAgent 需要 Xcode 编译、免费账号 7 天过期的签名证书、每台设备单独信任、以及常驻的测试进程。对一个以「随手可用」为目标的工具来说，这个代价不值得付。

## 它替你吸收的三个坑

**iOS 真机截图要 `--userspace`，不是 `--udid`。** `pymobiledevice3 developer dvt` 走 iOS 17+ RemoteXPC 隧道，只接受 `--rsd` / `--tunnel` / `--userspace`。传 `--udid`——最自然的猜测，也是多数博客的写法——会报 `Device not found`，把你引去排查一个根本不存在的连接问题。

**熄屏设备截图会「成功」，且是纯黑图。** 返回 0、文件写了、44KB 的空无一物。`mdev shot` 会对异常小的文件发出警告，让你去解锁设备而不是去调试隧道。

**`devicectl list devices` 会列出你配对过的所有设备。** 只有 `tunnelState == "connected"` 才是真正可达的，`mdev ls` 已经过滤。另外它的 JSON 必须写到真实文件，`--json-output /dev/stdout` 拿到的是无法解析的脏数据。

## 配合 Claude Code 使用

这个仓库同时是一个 [Claude Code](https://claude.com/claude-code) skill，让 AI 代理能看到并驱动你的设备——「给我 iPad 截个图」「装上这个包然后看日志」「现在屏幕上是什么」。

`install.sh` 会询问是否把仓库软链到 `~/.claude/skills/mobile-device`。[`SKILL.md`](SKILL.md) 里带着上面的能力矩阵和三个坑，这样代理不会浪费回合去尝试物理上不可能的事。

## 验证状态

已在 macOS 26 上针对 iPadOS 26.6（真机，有线）和 iOS 模拟器 26.x 验证。
Android 部分使用标准 `adb` 调用，但尚未在真实 Android 设备上跑过——欢迎反馈。

Linux 与 Windows：Android 那一半在 `adb` 能跑的地方就能跑；所有 iOS 功能仅限 macOS，其他平台会自动跳过。

## 许可证

MIT
