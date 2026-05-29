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

echo "▶ Step 1/4 — Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this session (Apple Silicon path)
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "▶ Step 2/4 — brew bundle (formulae, casks, App Store)"
brew bundle --file="$REPO_DIR/Brewfile"

echo "▶ Step 3/4 — Vendor AI CLIs"
mkdir -p "$HOME/.local/bin"

# Claude Code (Anthropic)
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Factory droid
if ! command -v droid >/dev/null 2>&1; then
  curl -fsSL https://app.factory.ai/cli | sh
fi

# Cursor agent
if ! command -v cursor-agent >/dev/null 2>&1; then
  curl -fsSL https://cursor.com/install | bash || \
    echo "  ⚠ Cursor install URL may have changed — check cursor.com for current command"
fi

# uv (Astral Python)
if ! command -v uv >/dev/null 2>&1; then
  curl -fsSL https://astral.sh/uv/install.sh | sh
fi

# OpenAI Codex CLI ships inside Codex.app — symlink it onto PATH if present
CODEX_APP="/Applications/Codex.app/Contents/Resources/codex"
if [ -x "$CODEX_APP" ] && [ ! -e "$HOME/.local/bin/codex" ]; then
  ln -s "$CODEX_APP" "$HOME/.local/bin/codex"
  echo "  ✓ linked Codex CLI from Codex.app"
fi

echo "▶ Step 4/4 — macOS defaults"
bash "$REPO_DIR/macos.sh"

echo ""
echo "✅ Bootstrap complete."
echo ""
echo "Reminders:"
echo "  • Add ~/.local/bin to PATH if not already (export PATH=\"\$HOME/.local/bin:\$PATH\")"
echo "  • Codex desktop app isn't in this Brewfile — install from openai.com if you want it"
echo "  • Run 'brew bundle check --file=$REPO_DIR/Brewfile' to verify"
