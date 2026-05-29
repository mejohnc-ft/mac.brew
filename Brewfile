# ~/Brewfile — personal machine baseline (formulae + casks)
#
# App Store apps are in a separate file: Brewfile.appstore
# That file is run conditionally during bootstrap.sh only after
# Apple ID + App Store sign-in is confirmed.

tap "supabase/tap"

# ─── Formulae ───────────────────────────────
# Shell & core
brew "bash"
brew "util-linux"
brew "wget"

# Git
brew "git"
brew "gh"
brew "git-filter-repo"

# Dev tools
brew "jq"
brew "poppler"
brew "ffmpeg"
brew "yt-dlp"
brew "mtr"

# Databases
brew "libpq"
brew "postgresql@16"
brew "postgresql@18"
brew "supabase/tap/supabase"

# App Store CLI (App Store *apps* live in Brewfile.appstore)
brew "mas"

# Dock layout
brew "dockutil"

# TUI toolkit (used by bootstrap.sh)
brew "gum"

# ─── Casks ──────────────────────────────────
# Productivity / utilities
cask "1password"
cask "1password-cli"
cask "appcleaner"
cask "bettertouchtool"
cask "obsidian"
# TinkerTool is freeware from bresink.com — not in Homebrew.
# Manual download: https://www.bresink.com/osx/TinkerTool.html

# Audio (Rogue Amoeba)
cask "audio-hijack"
cask "loopback"
cask "soundsource"

# Browsers / chat
cask "google-chrome"
cask "discord"

# Dev
cask "visual-studio-code"
cask "docker-desktop"
brew "powershell"   # formula, not cask
cask "warp"

# Networking
cask "tailscale-app"

# Dictation
cask "superwhisper"
