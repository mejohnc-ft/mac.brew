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

# ──────────────────────────────────────────────────────────────────
# Styling helpers — fall back to plain echo if gum isn't installed
# (gum gets installed during step 3; earlier steps use plain output)
# ──────────────────────────────────────────────────────────────────
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

ok()   { if command -v gum >/dev/null 2>&1; then gum style --foreground 42  "  ✓ $*"; else echo "  ✓ $*"; fi; }
warn() { if command -v gum >/dev/null 2>&1; then gum style --foreground 214 "  ⚠ $*"; else echo "  ⚠ $*"; fi; }
info() { if command -v gum >/dev/null 2>&1; then gum style --foreground 244 "  ⓘ $*"; else echo "  ⓘ $*"; fi; }

ask_yes() {
  local prompt="$1"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$prompt"
  else
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
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

deep_link() {
  open "$1" >/dev/null 2>&1 || true
  sleep 1  # let the pane register before user looks
}

# ──────────────────────────────────────────────────────────────────

banner "Mac Setup" "Personal baseline restoration" "mejohnc-ft/mac.brew"

# ─── Step 1: System check ─────────────────────────────────────────
step "1/14" "System check"
info "macOS:   $(sw_vers -productVersion)"
info "User:    $USER  •  Home: $HOME"
info "Disk:    $(df -h "$HOME" | awk 'NR==2 {print $4}') available"

# ─── Step 2: Homebrew ─────────────────────────────────────────────
step "2/14" "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
ok "Homebrew ready"

# ─── Step 3: brew bundle (no App Store apps yet) ─────────────────
step "3/14" "brew bundle — formulae + casks (no App Store apps yet)"

# Cache sudo so cask PKG installers (Docker, Tailscale, Rogue Amoeba apps)
# don't prompt repeatedly during the next few minutes.
if sudo -n true 2>/dev/null; then
  info "sudo already cached"
else
  echo "  → caching sudo for the next ~15 min (one password prompt)…"
  sudo -v
fi
# Background keepalive: refresh sudo timestamp every minute while the
# script runs. Auto-exits when the parent process exits.
( while true; do sudo -n true; sleep 60; kill -0 $$ 2>/dev/null || exit; done ) >/dev/null 2>&1 &
SUDO_KEEPER_PID=$!
# shellcheck disable=SC2064
trap "kill $SUDO_KEEPER_PID 2>/dev/null || true" EXIT
ok "sudo cached (background keepalive PID $SUDO_KEEPER_PID)"

# Run brew bundle tolerantly — partial failures (network blips, renamed
# casks, etc.) should NOT kill the rest of bootstrap.
if brew bundle --file="$REPO_DIR/Brewfile"; then
  ok "All core packages installed"
else
  warn "Some packages failed to install"
  echo
  echo "  Missing packages:"
  brew bundle check --verbose --file="$REPO_DIR/Brewfile" 2>&1 | sed 's/^/    /' || true
  echo
  info "Continuing to next step. Retry later with:"
  info "  brew bundle --file=$REPO_DIR/Brewfile"
fi

# ─── Step 4: Apple ID sign-in ────────────────────────────────────
step "4/14" "Apple ID sign-in"
APPLE_OK=0
if ask_yes "Open System Settings to sign into Apple ID? (needed for App Store + iCloud)"; then
  deep_link "x-apple.systempreferences:com.apple.preferences.AppleIDPrefPane"
  if ask_yes "Apple ID signed in?"; then
    APPLE_OK=1
    ok "Apple ID confirmed"
  else
    warn "Apple ID skipped — App Store apps will be skipped"
  fi
else
  warn "Apple ID skipped — App Store apps will be skipped"
fi

# ─── Step 5: App Store apps via mas ──────────────────────────────
step "5/14" "App Store apps"
if [ "$APPLE_OK" -eq 1 ]; then
  if mas account >/dev/null 2>&1; then
    ok "mas sees the App Store session"
  else
    info "mas can't see a session yet. Opening App Store app…"
    deep_link "macappstore://"
    if ! ask_yes "Signed into the App Store app?"; then
      warn "App Store skipped — run later: brew bundle --file=$REPO_DIR/Brewfile.appstore"
      APPLE_OK=0
    fi
  fi

  if [ "$APPLE_OK" -eq 1 ]; then
    if brew bundle --file="$REPO_DIR/Brewfile.appstore"; then
      ok "App Store apps installed"
    else
      warn "Some App Store installs failed (re-run later if needed)"
      brew bundle check --verbose --file="$REPO_DIR/Brewfile.appstore" 2>&1 | sed 's/^/    /' || true
    fi
  fi
else
  info "Skipping App Store apps. Run later when ready:"
  info "  brew bundle --file=$REPO_DIR/Brewfile.appstore"
fi

# ─── Step 6: 1Password unlock ────────────────────────────────────
step "6/14" "1Password unlock"
if [ -d /Applications/1Password.app ]; then
  if ask_yes "Open 1Password to sign in and enable Touch ID + CLI?"; then
    open -a 1Password
    info "In 1Password: Settings → Developer → enable 'Integrate with 1Password CLI'"
    info "Also: Settings → Security → Touch ID"
    ask_yes "1Password unlocked and CLI integration enabled?" || \
      warn "1Password not fully set up — future SSH key / Tailscale auth steps will need manual handling"
  else
    info "1Password unlock skipped — revisit later for SSH keys / app passwords"
  fi
else
  warn "1Password.app not installed (cask should have provided it in step 3)"
fi

# ─── Step 7: Vendor AI CLIs (install) ────────────────────────────
step "7/14" "Install vendor AI CLIs"
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
    warn "Cursor install URL may have changed"
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
ok "AI CLIs installed"

# Make them available to this shell for step 8
export PATH="$HOME/.local/bin:$PATH"

# ─── Step 8: AI CLI auth (interactive per tool) ──────────────────
step "8/14" "Authorize AI CLIs (each launches its own browser flow)"
authorize() {
  local name="$1" cmd="$2"
  command -v "$cmd" >/dev/null 2>&1 || { warn "$name not installed, skipping"; return; }
  if ask_yes "Launch $name now to sign in? (browser opens for auth)"; then
    info "After the browser auth completes, return to this terminal and exit the CLI (Ctrl+D or /exit)."
    "$cmd" || true  # tool's own exit code, not a failure for us
    ok "$name auth flow finished"
  else
    info "Skipped — run '$cmd' manually later to authorize"
  fi
}
authorize "Claude Code"   claude
authorize "Factory droid" droid
authorize "OpenAI Codex"  codex
authorize "Cursor agent"  cursor-agent

# ─── Step 9: Symlink personal dotfiles ───────────────────────────
step "9/14" "Symlink personal dotfiles"
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

# ─── Step 10: Restore AI tool configs ────────────────────────────
step "10/14" "Restore AI tool configs"
mkdir -p "$HOME/.claude" "$HOME/.codex"
run_spin "Syncing ~/.claude (skills, agents, hooks, settings)…" \
  rsync -a --ignore-existing "$REPO_DIR/configs/ai/claude/" "$HOME/.claude/"
run_spin "Syncing ~/.codex (skills, rules, keybindings, config)…" \
  rsync -a --ignore-existing "$REPO_DIR/configs/ai/codex/"  "$HOME/.codex/"
ok "AI configs restored"
info "Claude plugins still need /plugin install after first run:"
info "  /plugin install frontend-design@claude-plugins-official"
info "  /plugin marketplace add warpdotdev/claude-code-warp"
info "  /plugin install warp@claude-code-warp"

# ─── Step 11: Pin Dock apps ──────────────────────────────────────
step "11/14" "Pin Dock apps"
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
  warn "dockutil not found — skipping"
fi

# ─── Step 12: macOS UI + power defaults ──────────────────────────
step "12/14" "macOS UI + power defaults"
run_spin "Applying Dock / Finder / keyboard / screenshots / Safari…" \
  bash "$REPO_DIR/macos.sh"
run_spin "Applying liberal pmset sleep settings (uses cached sudo)…" \
  bash "$REPO_DIR/power.sh"
ok "macOS + power defaults applied"

# ─── Step 13: Permission grants (interactive) ────────────────────
step "13/14" "Permission grants (interactive — each opens System Settings)"
permission_grant() {
  local pane_id="$1" pane_name="$2" reason="$3"
  if ask_yes "Grant $pane_name now? ($reason)"; then
    deep_link "x-apple.systempreferences:com.apple.preference.security?Privacy_$pane_id"
    ask_yes "Done granting access in $pane_name?" || \
      warn "$pane_name marked incomplete — revisit System Settings later"
  else
    info "Skipped $pane_name"
  fi
}
permission_grant "Accessibility" "Accessibility" \
  "needed by BetterTouchTool, superwhisper, TextSniper"
permission_grant "ScreenCapture" "Screen Recording" \
  "needed by TextSniper, Loopback if installed"
permission_grant "ListenEvent"   "Input Monitoring" \
  "needed by BetterTouchTool"
permission_grant "AllFiles"      "Full Disk Access" \
  "needed for Terminal so Safari prefs in macos.sh apply"

# ─── Step 14: Agent review ───────────────────────────────────────
step "14/14" "Agent review (optional)"
if command -v claude >/dev/null 2>&1 && ask_yes "Run Claude Code to verify the setup end-to-end?"; then
  PROMPT="$(cat <<EOF
You are reviewing a fresh-mac bootstrap that just ran. Verify the
baseline from $REPO_DIR. Check and report ✓/⚠/✗ for each:

1. \`brew bundle check --file=$REPO_DIR/Brewfile\` — anything missing?
2. \`brew bundle check --file=$REPO_DIR/Brewfile.appstore\` — App Store apps installed?
3. ~/.claude exists with: settings.json, hooks/, agents/, skills/.
4. ~/.codex exists with: config.toml, skills/, rules/.
5. Dotfile symlinks resolved: ~/.zshrc, ~/.gitconfig,
   ~/.config/zed/settings.json, ~/.config/gh/config.yml.
6. Dock layout via \`defaults read com.apple.dock persistent-apps\`:
   1Password, Chrome, Music, Drafts, Warp, Discord.
7. macOS defaults: dock autohide on, finder shows hidden files,
   screenshots dir is ~/Screenshots, dark mode on.
8. AI CLI auth: \`claude auth status\` and similar for codex/droid.

Output a markdown table: Category | Status | Notes.
End with one line: "Setup is X% complete."
EOF
)"
  echo "$PROMPT" | claude --print 2>&1 || warn "claude review failed (may need re-auth)"
else
  info "Skipped agent review"
fi

# ─── Summary ─────────────────────────────────────────────────────
if command -v gum >/dev/null 2>&1; then
  gum style --border rounded --margin "1 2" --padding "1 3" \
    --border-foreground 42 --foreground 42 \
    "✅ Bootstrap complete"
fi

cat <<EOF

What still needs sign-in / cloud sync (no automation possible):
  • VS Code Settings Sync       — GitHub login from inside Code
  • BetterTouchTool             — account sync or restore local preset
  • Tailscale, Paste, Discord, Docker Desktop, Obsidian            — sign-in
  • Touch ID enrollment, Wi-Fi passwords, Bluetooth pairings       — System Settings

Maintenance later:
  brew update && brew upgrade
  brew bundle check --file=$REPO_DIR/Brewfile
  brew bundle check --file=$REPO_DIR/Brewfile.appstore
EOF
