#!/usr/bin/env bash
# bootstrap.sh — set up a fresh Mac to match this baseline.
#
# Usage:
#   gh repo clone mejohnc-ft/mac.brew ~/mac-setup
#   bash ~/mac-setup/bootstrap.sh
#
# Prerequisites:
#   1. Sign into the Mac App Store manually (mas can't log in for you).
#   2. Have network access.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "▶ Step 1/6 — Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "▶ Step 2/6 — brew bundle (formulae, casks, App Store)"
brew bundle --file="$REPO_DIR/Brewfile"

echo "▶ Step 3/6 — Vendor AI CLIs"
mkdir -p "$HOME/.local/bin"

if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
if ! command -v droid >/dev/null 2>&1; then
  curl -fsSL https://app.factory.ai/cli | sh
fi
if ! command -v cursor-agent >/dev/null 2>&1; then
  curl -fsSL https://cursor.com/install | bash || \
    echo "  ⚠ Cursor install URL may have changed — check cursor.com"
fi
if ! command -v uv >/dev/null 2>&1; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
fi

CODEX_APP="/Applications/Codex.app/Contents/Resources/codex"
if [ -x "$CODEX_APP" ] && [ ! -e "$HOME/.local/bin/codex" ]; then
  ln -s "$CODEX_APP" "$HOME/.local/bin/codex"
  echo "  ✓ linked Codex CLI from Codex.app"
fi

echo "▶ Step 4/6 — Symlink personal dotfiles"
# Each pair: source-in-repo → target-on-disk.
# Existing files are backed up to *.bak before being replaced.
link_config() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "${dest}.bak.$(date +%s)"
    echo "  ⚠ backed up existing $dest"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  echo "  ✓ $dest → $src"
}

link_config "$REPO_DIR/configs/zshrc"             "$HOME/.zshrc"
link_config "$REPO_DIR/configs/gitconfig"         "$HOME/.gitconfig"
link_config "$REPO_DIR/configs/zed/settings.json" "$HOME/.config/zed/settings.json"
link_config "$REPO_DIR/configs/gh/config.yml"     "$HOME/.config/gh/config.yml"

echo "▶ Step 5/6 — Pin Dock apps"
if command -v dockutil >/dev/null 2>&1; then
  dockutil --no-restart --remove all >/dev/null 2>&1 || true
  for app in \
      "/Applications/1Password.app" \
      "/Applications/Google Chrome.app" \
      "/System/Applications/Music.app" \
      "/Applications/Drafts.app" \
      "/Applications/Warp.app"; do
    [ -d "$app" ] && dockutil --no-restart --add "$app" >/dev/null 2>&1 || \
      echo "  ⚠ skipped (not installed): $app"
  done
  # Last add (no --no-restart) restarts the Dock
  if [ -d "/Applications/Discord.app" ]; then
    dockutil --add "/Applications/Discord.app" >/dev/null 2>&1 || true
  else
    killall Dock >/dev/null 2>&1 || true
  fi
  echo "  ✓ Dock pinned"
else
  echo "  ⚠ dockutil not found — skipping Dock pinning"
fi

echo "▶ Step 6/6 — macOS defaults"
bash "$REPO_DIR/macos.sh"

echo ""
echo "✅ Bootstrap complete."
echo ""
echo "Manual sign-ins still needed (cloud-synced apps):"
echo "  • Apple ID / iCloud (System Settings)"
echo "  • 1Password               — restores all passwords + SSH keys"
echo "  • VS Code Settings Sync   — sign in with GitHub from Code"
echo "  • BetterTouchTool         — restore preset (account sync or local JSON)"
echo "  • Tailscale               — sign in"
echo "  • Paste                   — App Store account sync"
echo "  • Discord                 — sign in"
echo "  • Obsidian                — open vault (sync via Obsidian Sync, iCloud, or git)"
echo "  • Docker Desktop          — sign in if you use Docker Hub"
echo "  • Claude Code / droid / cursor-agent / codex — re-auth each CLI"
echo ""
echo "Permission grants needed (System Settings → Privacy & Security):"
echo "  • Accessibility:     BetterTouchTool, superwhisper, TextSniper"
echo "  • Screen Recording:  TextSniper, Loopback (if used)"
echo "  • Input Monitoring:  BetterTouchTool"
echo "  • Full Disk Access:  Terminal (so Safari prefs in macos.sh apply)"
