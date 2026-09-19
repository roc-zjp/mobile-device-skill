#!/usr/bin/env bash
# Symlink mdev onto your PATH, and optionally install the Claude Code skill.
# Everything is a symlink, so `git pull` updates the installed copy in place.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${MDEV_BIN_DIR:-$HOME/.local/bin}"
SKILL_DIR="$HOME/.claude/skills/mobile-device"
WANT_SKILL="ask"

for arg in "$@"; do
  case "$arg" in
    --skill)    WANT_SKILL="yes" ;;
    --no-skill) WANT_SKILL="no" ;;
    -h|--help)
      echo "usage: ./install.sh [--skill | --no-skill]"
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { echo "x python3 is required" >&2; exit 1; }

# --- the CLI -----------------------------------------------------------------
mkdir -p "$BIN_DIR"
ln -sfn "$REPO/scripts/mdev" "$BIN_DIR/mdev"
echo "* mdev -> $BIN_DIR/mdev"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "  ! $BIN_DIR is not on your PATH. Add this to your shell profile:"
     echo "      export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

# --- the Claude Code skill ---------------------------------------------------
if [ "$WANT_SKILL" = "ask" ]; then
  if [ -t 0 ]; then
    printf "Install the Claude Code skill into ~/.claude/skills? [Y/n] "
    read -r reply
    case "$reply" in [Nn]*) WANT_SKILL="no" ;; *) WANT_SKILL="yes" ;; esac
  else
    WANT_SKILL="no"      # non-interactive: do not touch the user's skills dir
  fi
fi

if [ "$WANT_SKILL" = "yes" ]; then
  mkdir -p "$(dirname "$SKILL_DIR")"
  if [ -e "$SKILL_DIR" ] && [ ! -L "$SKILL_DIR" ]; then
    # A real directory is already there - never delete it silently.
    backup="$SKILL_DIR.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$SKILL_DIR" "$backup"
    echo "  ! existing directory moved to $backup"
  fi
  ln -sfn "$REPO" "$SKILL_DIR"
  echo "* skill -> $SKILL_DIR"
fi

# --- what is actually available ---------------------------------------------
echo
echo "Platform tools detected:"
for tool in adb scrcpy pymobiledevice3; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ok      $tool"
  elif [ "$tool" = "adb" ] && [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
    echo "  ok      adb (Android SDK, located automatically)"
  else
    echo "  missing $tool"
  fi
done
if command -v xcrun >/dev/null 2>&1; then
  echo "  ok      xcrun (simctl / devicectl)"
else
  echo "  missing xcrun - iOS support needs Xcode command line tools"
fi

echo
echo "Done. Try: mdev ls"
