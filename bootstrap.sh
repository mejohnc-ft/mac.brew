#!/usr/bin/env bash
# bootstrap.sh — set up a fresh Mac to match this baseline.
#
# Usage (new mac):
#   curl -fsSL https://mejohnc.org/mac | bash
#
# Or directly:
#   gh repo clone mejohnc-ft/mac.brew ~/mac-setup
#   bash ~/mac-setup/bootstrap.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────────────────────────
# Styling helpers — fall back to plain echo if gum isn't installed
# (gum gets installed during step 2; steps 1-2 are plain text)
# ─────────────────────────────────────────────────────────────────
banner() {
  if command -v gum >/dev/null 2>&1; then
    gum style --border double --margin "1 2" --padding "1 4" \
      --border-foreground 212 --foreground 212 --align center --width 50 \
      "$@"
  else
    echo
    echo "═══════════════════════════════════════════════════"
    for line in "$@"; do echo "  $line"; done
    echo "═══════════════════════════════════════════════════"
  fi
}

step() {
  local num="$1" desc="$2"
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 99 --bold "▶ Step $num — $desc"
  else
    echo "▶ Step $num — $desc"
  fi
}

ok() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 42 "  ✓ $*"
  else
    echo "  ✓ $*"
  fi
}

warn() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 214 "  ⚠ $*"
  else
    echo "  ⚠ $*"
  fi
}

info() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 244 "  ⓘ $*"
  else
    echo "  ⓘ $*"
  fi
}

run_spin() {
  local title="$1"; shift
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "$title" --show-output -- "$@"
  else
    echo "  → $title"
    "$@"
  fi
}

# ─────────────────────────────────────────────────────────────────

banner "Mac Setup" "Personal baseline restoration" "mejohnc-ft/mac.brew"

step "1/8" "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
ok "Homebrew ready"

step "2/8" "brew bundle — formulae, casks, App Store"
brew bundle --file="$REPO_DIR/Brewfile"
ok "brew bundle complete"

# From here on, gum is installed and available
step "3/8" "Vendor AI CLIs"
mkdir -p "$HOME/.local/bin"

if ! command -v claude >/dev/null 2>&1; then
  run_spin "Installing Claude Code…" \
    bash -c "curl -fsSL https://claude.ai/install.sh | bash"
fi
if ! command -v droid >/dev/null 2>&1; then
  run_spin "Installing Factory droid…" \
    bash -c "curl -fsSL https://app.factory.ai/cli | sh"
fi
if ! command -v cursor-agent >/dev/null 2>&1; then
  run_spin "Installing cursor-agent…" \
    bash -c "curl -fsSL https://cursor.com/install | bash" || \
    warn "Cursor install URL may have changed — check cursor.com"
fi
if ! command -v uv >/dev/null 2>&1; then
  run_spin "Installing uv…" \
    bash -c "curl -fsSL https://astral.sh/uv/install.sh | sh"
fi

CODEX_APP="/Applications/Codex.app/Contents/Resources/codex"
if [ -x "$CODEX_APP" ] && [ ! -e "$HOME/.local/bin/codex" ]; then
  ln -s "$CODEX_APP" "$HOME/.local/bin/codex"
  ok "linked Codex CLI from Codex.app"
fi
ok "AI CLIs ready"

step "4/8" "Symlink personal dotfiles"
link_config() {
  local src="$1" dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "${dest}.bak.$(date +%s)"
    warn "backed up existing $dest"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -sfn "$src" "$dest"
  ok "$(basename "$dest") → $src"
}

link_config "$REPO_DIR/configs/zshrc"             "$HOME/.zshrc"
link_config "$REPO_DIR/configs/gitconfig"         "$HOME/.gitconfig"
link_config "$REPO_DIR/configs/zed/settings.json" "$HOME/.config/zed/settings.json"
link_config "$REPO_DIR/configs/gh/config.yml"     "$HOME/.config/gh/config.yml"

step "5/8" "Restore AI tool configs"
mkdir -p "$HOME/.claude" "$HOME/.codex"
run_spin "Syncing ~/.claude (skills, agents, hooks, settings)…" \
  rsync -a --ignore-existing "$REPO_DIR/configs/ai/claude/" "$HOME/.claude/"
run_spin "Syncing ~/.codex (skills, rules, keybindings, config)…" \
  rsync -a --ignore-existing "$REPO_DIR/configs/ai/codex/"  "$HOME/.codex/"
ok "AI configs restored"
info "Claude plugins must be re-installed after sign-in:"
info "  /plugin install frontend-design@claude-plugins-official"
info "  /plugin marketplace add warpdotdev/claude-code-warp"
info "  /plugin install warp@claude-code-warp"

step "6/8" "Pin Dock apps"
if command -v dockutil >/dev/null 2>&1; then
  dockutil --no-restart --remove all >/dev/null 2>&1 || true
  for app in \
      "/Applications/1Password.app" \
      "/Applications/Google Chrome.app" \
      "/System/Applications/Music.app" \
      "/Applications/Drafts.app" \
      "/Applications/Warp.app"; do
    if [ -d "$app" ]; then
      dockutil --no-restart --add "$app" >/dev/null 2>&1
    else
      warn "skipped (not installed): $(basename "$app")"
    fi
  done
  if [ -d "/Applications/Discord.app" ]; then
    dockutil --add "/Applications/Discord.app" >/dev/null 2>&1 || true
  else
    killall Dock >/dev/null 2>&1 || true
  fi
  ok "Dock pinned"
else
  warn "dockutil not found — skipping Dock pinning"
fi

step "7/8" "macOS UI defaults"
run_spin "Applying Dock / Finder / keyboard / screenshots / Safari…" \
  bash "$REPO_DIR/macos.sh"
ok "macOS defaults applied"

step "8/8" "Agent review (optional)"
if command -v claude >/dev/null 2>&1 && \
   command -v gum >/dev/null 2>&1 && \
   gum confirm "Run Claude Code to verify the setup?"; then
  PROMPT="$(cat <<EOF
You are reviewing a fresh-mac bootstrap that just ran. Verify the
baseline from ~/mac-setup. Check and report ✓/⚠/✗ for each:

1. \`brew bundle check --file=$REPO_DIR/Brewfile\` — anything missing?
2. ~/.claude exists with subdirs: settings.json, hooks, agents, skills.
3. ~/.codex exists with: config.toml, skills, rules.
4. Symlinks present and resolved: ~/.zshrc, ~/.gitconfig,
   ~/.config/zed/settings.json, ~/.config/gh/config.yml.
5. Dock has the expected apps in order (use \`defaults read com.apple.dock\`):
   1Password, Chrome, Music, Drafts, Warp, Discord.
6. macOS defaults check: dock autohide on, finder shows hidden files,
   screenshots saving to ~/Screenshots, dark mode on.

Output a markdown table with columns: Category | Status | Notes.
End with a one-line summary: "Setup is X% complete."
EOF
)"
  echo "$PROMPT" | claude --print 2>&1 || warn "claude review failed (may need re-auth)"
else
  info "Skipping agent review (claude not available or declined)"
fi

# ─── Summary ────────────────────────────────────────────────────
if command -v gum >/dev/null 2>&1; then
  gum style --border rounded --margin "1 2" --padding "1 3" \
    --border-foreground 42 --foreground 42 \
    "✅ Bootstrap complete"
fi

cat <<'EOF'

Manual sign-ins still needed (cloud-synced apps):
  • Apple ID / iCloud           (System Settings)
  • 1Password                   — restores passwords + SSH keys
  • VS Code Settings Sync       — GitHub login from inside Code
  • BetterTouchTool             — account sync or local preset
  • Tailscale, Paste, Discord, Docker Desktop, Obsidian
  • Claude Code / droid / cursor-agent / codex — re-auth each CLI

Permission grants (System Settings → Privacy & Security):
  • Accessibility       — BetterTouchTool, superwhisper, TextSniper
  • Screen Recording    — TextSniper, Loopback (if used)
  • Input Monitoring    — BetterTouchTool
  • Full Disk Access    — Terminal (so Safari prefs in macos.sh apply)

Maintenance:
  brew update && brew upgrade
  brew bundle check --file=~/mac-setup/Brewfile
EOF
